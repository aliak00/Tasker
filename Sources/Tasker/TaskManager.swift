import Foundation

/**
 A task manager can be given an arbitrary number of `Task`s and initialized with a set of `TaskInterceptor`s
 and then takes care of asynchronous execution for you.
 */
public class TaskManager {
    public static let shared = TaskManager()

    /**
     Thes log tags can be passed to filter the logs produced by the TaskManager

     - SeeAlso `Logger'
     */
    public struct LoggerTag {
        public static let onTaskQueue = "tq"
        public static let onOperationQueue = "oq"
        public static let callback = "cb"
        public static let onReactorQueue = "rq"
        public static let caller = "caller"
    }

    private static let kOpQTags = [LoggerTag.onOperationQueue]
    private static let kCbOpQTags = [LoggerTag.onOperationQueue, LoggerTag.callback]
    private static let kTkQTags = [LoggerTag.onTaskQueue]
    private static let kCbReQTags = [LoggerTag.onReactorQueue, LoggerTag.callback]
    private static let kClrTags = [LoggerTag.caller]
    private static let kReQTags = [LoggerTag.onReactorQueue]

    static var counter = AtomicInt()

    private var pendingTasks: [Handle: Handle.Data] = [:]
    private let taskOperationQueue = OperationQueue()

    private let taskQueue = DispatchQueue(label: "Tasker.TaskManager.tasks")
    private let reactorQueue = DispatchQueue(label: "Tasker.TaskManager.reactors", attributes: [.concurrent])
    private let dispatchGroup = DispatchGroup()

    private let interceptorManager: TaskInterceptorManager

    private var executingReactors = Set<Int>()
    private var reactorAssoiciatedHandles: [Int: Set<Handle>] = [:] // TODO: Can/should these handles be weak?

    private var tasksToRequeue = Set<Handle>() // TODO: Can/should these handles be weak?
    private var tasksToBatch: [Int: [Weak<Handle>]] = [:]

    public let reactors: [TaskReactor]
    public var interceptors: [TaskInterceptor] {
        return self.interceptorManager.interceptors
    }

    let identifier: Int

    /**
     Initializes this manager object.

     - parameter interceptors: an array of interceptors that will be applied to every task before being started
     - parameter reactors: an array of reactors that will be applied to every task after it's executed
     */
    public init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = []) {
        self.taskOperationQueue.isSuspended = false
        self.reactors = reactors
        self.interceptorManager = TaskInterceptorManager(interceptors)
        self.identifier = type(of: self).counter.getAndIncrement()
    }

    /**
     Add a task to the manager. You may choose to start the task immediately or start if yourself via the `TaskHandle` that
     is returned. Additionally, you can also set an interval on when to start the task but that is only valid if `startImmediately`
     is set to true

     - parameter task: the task to run
     - parameter startImmediately: set this to false if you want to call start on the `TaskHandle` that's returned
     - parameter after: set this to some value if you want the task to start running after some interval
     - parameter completion: called after the task is done with the result of `Task.execute`
     */
    @discardableResult
    public func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        timeout: DispatchTimeInterval? = nil,
        completeOn completionQueue: DispatchQueue? = nil,
        completion: T.ResultCallback? = nil
    ) -> TaskHandle {
        let handle = Handle(owner: self)

        let operation = AsyncOperation { [weak self, weak task, weak handle] operation in

            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self) operation => manager dead", tags: TaskManager.kOpQTags)
                return
            }

            guard let handle = handle else {
                log(level: .verbose, from: self, "\(T.self) operation => handle dead", tags: TaskManager.kOpQTags)
                return
            }

            guard let task = task else {
                log(level: .verbose, from: self, "\(handle) operation => task dead", tags: TaskManager.kOpQTags)
                return
            }

            guard !operation.isCancelled else {
                log(level: .verbose, from: self, "\(handle) operation => operation cancelled", tags: TaskManager.kOpQTags)
                return
            }

            strongSelf.execute(task: task, handle: handle, operation: operation, timeout: timeout ?? task.timeout, completion: completion)
        }

        log(from: self,
            "will add \(handle) - "
                + "task: \(T.self), "
                + "interval: \(String(describing: interval)), "
                + "completionQueue: \(completionQueue?.label as Any)", tags: TaskManager.kClrTags)

        self.taskQueue.async { [weak self] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }

            let intercept: (DispatchTimeInterval?, @escaping (TaskInterceptorManager.InterceptResult) -> Void) -> Void = { [weak task, weak handle] interval, completion in
                guard let strongSelf = self, var task = task, let handle = handle else {
                    completion(.ignore)
                    return
                }
                strongSelf.interceptorManager.intercept(task: &task, for: handle, after: interval) { completion($0) }
            }

            let data = Handle.Data(
                operation: operation,
                taskReference: task,
                completionErrorCallback: { completion?(.failure($0)) },
                taskDidCancelCallback: { [weak task] in task?.didCancel(with: $0) },
                intercept: intercept,
                completionQueue: completionQueue
            )

            strongSelf.pendingTasks[handle] = data
            log(from: self, "did add \(handle)", tags: TaskManager.kTkQTags)

            if startImmediately {
                strongSelf.startTask(for: handle, with: data, after: interval)
            }
        }

        return handle
    }

    public func waitTillAllTasksFinished() {
        log(level: .verbose, from: self, "begin waiting")
        self.taskOperationQueue.waitUntilAllOperationsAreFinished()
        self.dispatchGroup.wait()
        log(level: .verbose, from: self, "end waiting")
    }

    private func execute<T: Task>(task: T, handle: Handle, operation: AsyncOperation, timeout: DispatchTimeInterval?, completion: T.ResultCallback?) {
        let timeoutWorkItem: DispatchWorkItem?
        if let timeout = timeout {
            timeoutWorkItem = self.launchTimeoutWork(for: handle, withTimeout: timeout)
        } else {
            timeoutWorkItem = nil
        }

        log(from: self, "will execute \(handle)", tags: TaskManager.kOpQTags)

        self.dispatchGroup.enter()
        task.execute { [weak self, weak task, weak handle, weak operation] result in
            defer { self?.dispatchGroup.leave() }

            timeoutWorkItem?.cancel()

            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self).execute manager dead", tags: TaskManager.kCbOpQTags)
                return
            }

            guard let handle = handle else {
                log(level: .verbose, from: strongSelf, "\(T.self).execute handle dead", tags: TaskManager.kCbOpQTags)
                return
            }

            guard let operation = operation, !operation.isCancelled else {
                log(level: .verbose, from: strongSelf, "executed \(handle) but operation dead or cancelled", tags: TaskManager.kTkQTags)
                return
            }

            log(from: strongSelf, "did execute \(handle)", tags: TaskManager.kCbOpQTags)

            // Get off whatever thread the task called the callback on
            strongSelf.taskQueue.async { [weak handle, weak operation] in
                guard let strongSelf = self else {
                    log(level: .verbose, from: self, "\(T.self).execute => manager dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let handle = handle else {
                    log(level: .verbose, from: strongSelf, "\(T.self).execute => handle dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let task = task else {
                    log(level: .verbose, from: strongSelf, "task.execute => task for \(handle) dead", tags: TaskManager.kCbOpQTags)
                    return
                }

                //
                // Now check if we need to execute any of the reactors. If we do and the reactor is configured
                // to requeue the task then we are done here. Else we fire up the reactors and finish the task
                //
                let reactionData = strongSelf.reactors.enumerated().reduce((indices: [Int](), requeueTask: false, suspendQueue: false)) { memo, pair in
                    let index = pair.offset
                    let reactor = pair.element
                    var indices = memo.indices
                    var requeueTask = memo.requeueTask
                    var suspendQueue = memo.suspendQueue
                    if reactor.shouldExecute(after: result, from: task, with: handle) {
                        indices.append(index)
                        requeueTask = memo.requeueTask || reactor.configuration.requeuesTask
                        suspendQueue = memo.suspendQueue || reactor.configuration.suspendsTaskQueue
                    }
                    return (indices, requeueTask, suspendQueue)
                }

                if reactionData.indices.count > 0 {
                    log(from: strongSelf,
                        "\(handle) launching reactors \(reactionData.indices) - "
                            + "after result \(result), "
                            + "requeue: \(reactionData.requeueTask), "
                            + "suspend: \(reactionData.suspendQueue)",
                        tags: TaskManager.kTkQTags)
                    strongSelf.launchReactors(
                        at: reactionData.indices,
                        on: handle,
                        requeueTask: reactionData.requeueTask,
                        suspendQueue: reactionData.suspendQueue
                    )

                    if reactionData.requeueTask {
                        return
                    }
                } else {
                    log(level: .debug, from: strongSelf, "\(handle) not causing reactors", tags: TaskManager.kTkQTags)
                }

                guard let operation = operation, !operation.isCancelled else {
                    log(level: .verbose, from: strongSelf, "task.execute => operation for \(handle) dead or cancelled", tags: TaskManager.kTkQTags)
                    return
                }

                log(level: .verbose, from: strongSelf, "will finish \(handle)", tags: TaskManager.kTkQTags)
                if let data = strongSelf.data(for: handle, remove: true) {
                    assert(data.operation === operation)
                    data.operation.finish()
                    log(level: .verbose, from: strongSelf, "did finish \(handle)", tags: TaskManager.kTkQTags)
                    (data.completionQueue ?? strongSelf.taskQueue).async {
                        completion?(result)
                    }
                } else {
                    log(level: .verbose, from: strongSelf, "did not finish \(handle)", tags: TaskManager.kTkQTags)
                }
            }
        }
    }

    private func data(for handle: Handle, remove: Bool = false) -> Handle.Data? {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        if remove {
            guard let data = self.pendingTasks.removeValue(forKey: handle) else {
                return nil
            }
            return data
        } else {
            guard let data = self.pendingTasks[handle] else {
                return nil
            }
            return data
        }
    }

    private func queueOperation(_ operation: AsyncOperation, for handle: Handle) {
        // Accessing Tasker.Operation so better be on task queue
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        self.taskOperationQueue.addOperation(operation)
        log(level: .verbose, from: self, "did queue \(handle)", tags: TaskManager.kTkQTags)
    }

    private func justQueueTask(for handle: Handle, with data: Handle.Data, after interval: DispatchTimeInterval? = nil) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        log(level: .verbose, from: self, "will queue \(handle)", tags: TaskManager.kTkQTags)
        guard let interval = interval else {
            self.queueOperation(data.operation, for: handle)
            return
        }
        self.taskQueue.asyncAfter(deadline: .now() + interval) { [weak self, weak handle] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let handle = handle else {
                log(level: .verbose, from: self, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let data = strongSelf.data(for: handle) else {
                log(level: .verbose, from: self, "will not queue \(handle)", tags: TaskManager.kTkQTags)
                return
            }
            strongSelf.queueOperation(data.operation, for: handle)
        }
    }

    private func interceptThenQueueTask(for handle: Handle, with data: Handle.Data, after interval: DispatchTimeInterval? = nil) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        data.intercept(interval) { [weak self, weak handle] result in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kClrTags)
                return
            }
            guard let handle = handle else {
                log(level: .verbose, from: self, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            guard case let .execute(handles) = result else {
                log(level: .verbose, from: self, "will not queue \(handle)")
                return
            }
            strongSelf.taskQueue.async {
                for handle in handles {
                    guard let strongSelf = self else {
                        log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                        return
                    }

                    guard let data = self?.data(for: handle) else {
                        continue
                    }
                    strongSelf.queueOperation(data.operation, for: handle)
                }
            }
        }
    }

    private func startTask(for handle: Handle, with data: Handle.Data, after interval: DispatchTimeInterval? = nil) {
        // Getting the raw TaskData here so we better be on the taskQueue
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        if self.interceptorManager.count == 0 {
            self.justQueueTask(for: handle, with: data, after: interval)
        } else {
            self.interceptThenQueueTask(for: handle, with: data, after: interval)
        }
    }

    private func launchTimeoutWork(for handle: Handle, withTimeout timeout: DispatchTimeInterval) -> DispatchWorkItem {
        var timeoutWorkItem: DispatchWorkItem!
        timeoutWorkItem = DispatchWorkItem { [weak self, weak handle] in
            guard let handle = handle else {
                log(level: .verbose, from: self, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            guard !timeoutWorkItem.isCancelled else {
                log(level: .verbose, from: self, "\(handle) timeoutWorkItem cancelled", tags: TaskManager.kTkQTags)
                return
            }
            self?.removeAndCancel(handle: handle, with: .timedOut)
        }
        self.taskQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
        return timeoutWorkItem
    }

    private func launchReactors(at indices: [Int], on finishedHandle: Handle, requeueTask: Bool, suspendQueue: Bool) {
        //
        // Executing the reactors involves the following:
        //
        // 1. Cull out reactors that are already executing
        // 2. Note down immediate reactors
        // 3. Queue up asynchronous reactors
        // 4. Execute immediate reactors
        // - If an interceptor says requeue a task, requeue
        // - If an interceptor says pause task queue, then pause
        // - When all queued reactors are done, restart task queue
        //
        self.taskQueue.async { [weak self, weak finishedHandle] in

            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }

            if requeueTask, let handle = finishedHandle {
                log(from: strongSelf, "saving \(handle) to requeue list", tags: TaskManager.kTkQTags)
                strongSelf.tasksToRequeue.insert(handle)

                // Associate this handle with the reactors only if it's supposed to be requeued
                for index in indices {
                    strongSelf.reactorAssoiciatedHandles[index] = strongSelf.reactorAssoiciatedHandles[index] ?? Set<Handle>()
                    strongSelf.reactorAssoiciatedHandles[index]?.insert(handle)
                }
            } else {
                log(level: .verbose, from: strongSelf, "handle dead, cannot requeue", tags: TaskManager.kTkQTags)
            }

            // No need to run executors that are already executing
            let reactorIndices = Set(indices).subtracting(strongSelf.executingReactors)
            guard reactorIndices.count > 0 else {
                log(from: strongSelf, "already executing \(strongSelf.executingReactors)", tags: TaskManager.kTkQTags)
                return
            }

            if suspendQueue {
                log(from: strongSelf, "suspending task queue", tags: TaskManager.kTkQTags)
                strongSelf.taskOperationQueue.isSuspended = true
            }

            var immediateReactorIndices = Set<Int>()

            for index in reactorIndices {
                let reactor = strongSelf.reactors[index]

                // If reactor is immediate than mark it and move on
                if reactor.configuration.isImmediate {
                    log(level: .verbose, from: strongSelf, "adding immediate reactor \(index): \(reactor.self)", tags: TaskManager.kTkQTags)
                    immediateReactorIndices.insert(index)
                    continue
                }

                var maybeTimeoutWorkItem: DispatchWorkItem?
                var reactorWorkItem: DispatchWorkItem!

                reactorWorkItem = DispatchWorkItem { [weak self] in
                    guard let strongSelf = self else {
                        log(level: .verbose, from: self, "manager dead", tags: TaskManager.kReQTags)
                        return
                    }

                    log(from: strongSelf, "will execute reactor \(index): \(reactor.self)", tags: TaskManager.kReQTags)

                    reactor.execute { [weak self] maybeError in

                        maybeTimeoutWorkItem?.cancel()

                        guard let strongSelf = self else {
                            log(level: .verbose, from: self, "manager dead", tags: TaskManager.kCbReQTags)
                            return
                        }

                        guard !reactorWorkItem.isCancelled else {
                            log(level: .verbose, from: strongSelf, "reactor \(index) cancelled", tags: TaskManager.kCbReQTags)
                            return
                        }

                        log(from: strongSelf, "did execute reactor \(index)", tags: TaskManager.kCbReQTags)

                        // Get off of whichever queue reactor execute completed on
                        strongSelf.taskQueue.async { [weak self] in
                            guard let strongSelf = self else {
                                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                                return
                            }

                            if let error = maybeError {
                                strongSelf.cancelAssociatedTasksForReactor(at: index, with: .reactorFailed(type: type(of: reactor), error: error))
                            }

                            strongSelf.removeExecutingReactor(at: index)
                            log(from: strongSelf, "removed reactor \(index)", tags: TaskManager.kTkQTags)
                        }
                    }
                }

                strongSelf.executingReactors.insert(index)
                strongSelf.reactorQueue.async(execute: reactorWorkItem)

                // Give the async interceptor operation a timeout to complete
                if let timeout = reactor.configuration.timeout {
                    let timeoutWorkItem = DispatchWorkItem { [weak self] in

                        strongSelf.taskQueue.async {
                            reactorWorkItem.cancel()

                            guard let timeoutWorkItem = maybeTimeoutWorkItem, !timeoutWorkItem.isCancelled else {
                                log(from: self, "\(index) timeout work cancelled", tags: TaskManager.kTkQTags)
                                return
                            }

                            guard let strongSelf = self else {
                                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kReQTags)
                                return
                            }

                            log(from: strongSelf, "reactor \(index) timed out", tags: TaskManager.kTkQTags)

                            strongSelf.cancelAssociatedTasksForReactor(at: index, with: .reactorTimedOut(type: type(of: reactor)))
                            strongSelf.removeExecutingReactor(at: index)
                        }
                    }

                    maybeTimeoutWorkItem = timeoutWorkItem
                    strongSelf.reactorQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
                }
            }

            strongSelf.reactorQueue.sync {
                strongSelf.executeImmediateReactors(at: Array(immediateReactorIndices))
            }

            // If we only had immediate reactors make sure queue is suspended and requeue tasks
            if strongSelf.executingReactors.count == 0 {
                log(from: strongSelf, "unsuspending task queue", tags: TaskManager.kTkQTags)
                strongSelf.taskOperationQueue.isSuspended = false
                strongSelf.requeueTasks()
            }
        }
    }

    private func requeueTasks() {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        for handle in self.tasksToRequeue {
            if let data = self.data(for: handle) {
                log(from: self, "requeueing \(handle)", tags: TaskManager.kTkQTags)
                data.operation.finish()
                data.operation = AsyncOperation(executor: data.operation.executor)
                self.queueOperation(data.operation, for: handle)
            }
        }
        self.tasksToRequeue = Set<Handle>()
    }

    private func executeImmediateReactors(at indicies: [Int]) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        DispatchQueue.concurrentPerform(iterations: indicies.count) { index in
            let semaphore = DispatchSemaphore(value: 0)
            let reactor = self.reactors[index]
            log(from: self, "executing immediate reactor \(reactor.self)", tags: TaskManager.kReQTags)
            var maybeError: TaskError?
            reactor.execute { error in
                if let error = error {
                    maybeError = .reactorFailed(type: type(of: reactor), error: error)
                }
                semaphore.signal()
            }
            if let timeout = reactor.configuration.timeout, semaphore.wait(timeout: .now() + timeout) == .timedOut {
                maybeError = .reactorTimedOut(type: type(of: reactor))
            } else {
                semaphore.wait()
            }
            guard let error = maybeError else {
                log(from: self, "executed immediate reactor \(reactor.self)", tags: TaskManager.kReQTags)
                return
            }
            log(from: self, "immediate reactor \(reactor.self) failed with: \(error)", tags: TaskManager.kReQTags)
            self.taskQueue.async { [weak self] in
                self?.cancelAssociatedTasksForReactor(at: index, with: .reactorFailed(type: type(of: reactor), error: error))
            }
        }
    }

    private func cancelAssociatedTasksForReactor(at index: Int, with error: TaskError) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        var allTheData: [Handle.Data] = []
        for handle in self.reactorAssoiciatedHandles[index] ?? Set<Handle>() {
            if let data = self.data(for: handle, remove: true) {
                log(from: self, "removed handle \(handle) for reactor \(index)", tags: TaskManager.kTkQTags)
                data.operation.cancel()
                data.taskDidCancelCallback(error)
                allTheData.append(data)
                if self.tasksToRequeue.remove(handle) != nil {
                    log(from: self, "removed \(handle) from requeue list", tags: TaskManager.kTkQTags)
                }
            }
        }
        self.reactorAssoiciatedHandles[index]?.removeAll()
        for data in allTheData {
            (data.completionQueue ?? self.taskQueue).async {
                data.completionErrorCallback(error)
            }
        }
    }

    private func removeExecutingReactor(at index: Int) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        self.executingReactors.remove(index)
        if self.executingReactors.count == 0 {
            // Stop interceptor queue and ensure task queue is not suspended
            self.taskOperationQueue.isSuspended = false
            self.requeueTasks()
        }
    }

    private func removeAndCancel(handle: Handle, with error: TaskError?) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        guard let data = self.data(for: handle, remove: true) else {
            return
        }
        log(from: self, "removed \(handle) with error \(error as Any)", tags: TaskManager.kTkQTags)
        data.operation.cancel()
        guard let error = error else {
            return
        }
        data.taskDidCancelCallback(error)
        (data.completionQueue ?? self.taskQueue).async {
            data.completionErrorCallback(error)
        }
    }

    func cancel(handle: Handle, with error: TaskError?) {
        log(from: self, "cancelling \(handle)", tags: TaskManager.kClrTags)
        self.taskQueue.async { [weak self, weak handle] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let handle = handle else {
                log(level: .verbose, from: strongSelf, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            strongSelf.removeAndCancel(handle: handle, with: error)
        }
    }

    func start(handle: Handle) {
        self.taskQueue.async { [weak self, weak handle] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let handle = handle else {
                log(level: .verbose, from: strongSelf, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            if let data = strongSelf.data(for: handle) {
                strongSelf.startTask(for: handle, with: data)
            }
        }
    }

    func taskState(for handle: Handle) -> TaskState {
        let maybeOperation = self.taskQueue.sync { () -> AsyncOperation? in
            guard let data = self.data(for: handle) else {
                log(level: .verbose, from: self, "\(handle) not found", tags: TaskManager.kTkQTags)
                return nil
            }
            log(from: self, "\(handle) operation  is \(data.operation.state)", tags: TaskManager.kTkQTags)
            return data.operation
        }
        guard let operation = maybeOperation else {
            return .finished
        }
        switch (operation.state, operation.isCancelled) {
        case (.finished, _), (_, true):
            return .finished
        case (.executing, _):
            return .executing
        case (.ready, _):
            return .pending
        }
    }
}
