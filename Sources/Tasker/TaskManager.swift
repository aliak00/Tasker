import Foundation

/**
 A task manager can be given an arbitrary number of `Task`s and initialized with a set of `TaskInterceptor`s
 and `TaskReactor`s, after which it will take care of asynchonous task management for you.
 */
public class TaskManager {
    /**
     Shared TaskManager that is default constructed and has no `TaskInterceptor`s or `TaskReactor`s.
     */
    public static let shared = TaskManager()

    private static let kOpQTags = [LogTags.onOperationQueue]
    private static let kTkQTags = [LogTags.onTaskQueue]
    private static let kClrTags = [LogTags.caller]
    private static let kReQTags = [LogTags.onReactorQueue]

    private static var identifierCounter = AtomicInt()

    private var pendingTasks: [Handle: Handle.Data] = [:]
    private let operationQueue = OperationQueue()

    private let taskQueue = DispatchQueue(label: "Tasker.TaskManager.tasks")
    private let reactorQueue = DispatchQueue(label: "Tasker.TaskManager.reactors", attributes: [.concurrent])

    private let interceptorManager: TaskInterceptorManager

    private var executingReactors = Set<Int>()
    private var reactorAssoiciatedHandles: [Int: Set<Handle>] = [:] // TODO: Can/should these handles be weak?

    private var tasksToRequeue = Set<Handle>() // TODO: Can/should these handles be weak?
    private var tasksToBatch: [Int: [Weak<Handle>]] = [:]

    /**
     List of reactors that this TaskManager was created with
     */
    public let reactors: [TaskReactor]

    /**
     List of interceptors that this TaskManager was created with
     */
    public var interceptors: [TaskInterceptor] {
        return self.interceptorManager.interceptors
    }

    /**
     Identifies the TaskManager in question. It is an atomically increasing integer, per TaskManager created
     */
    public let identifier: Int

    /**
     Initializes this manager object.

     - parameter interceptors: an array of interceptors that will be applied to every task before being started
     - parameter reactors: an array of reactors that will be applied to every task after it's executed
     */
    public init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = []) {
        self.operationQueue.isSuspended = false
        self.reactors = reactors
        self.interceptorManager = TaskInterceptorManager(interceptors)
        self.identifier = type(of: self).identifierCounter.getAndIncrement()
    }

    deinit {
        // TODO: go through all handles and mark operations as finished
    }

    /**
     Add a task to the manager. You may choose to start the task immediately or start it yourself via the `TaskHandle` that
     is returned. Additionally, you can also set an interval on when to start the task but that is only valid if `startImmediately`
     is set to true

     - parameter task: the task to run
     - parameter startImmediately: set this to false if you want to explicity call start on the `TaskHandle` that's returned
     - parameter after: set this to some value if you want the task to start running after some interval
     - parameter timeout: after how long the task times out (overrides `Task.timeout`)
     - parameter completeOn: specifies which queue completion is called on
     - parameter completion: called after the task is done with the result of `Task.execute`
     */
    @discardableResult
    public func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        timeout: DispatchTimeInterval? = nil,
        completeOn completionQueue: DispatchQueue? = nil,
        completion: T.CompletionCallback? = nil
    ) -> TaskHandle {
        // Create a handle to this task, and also setup an Operation object that will be associated with this Task
        let handle = Handle(owner: self)
        let operation = self.createAsyncOperationForHandle(handle, task: task, timeout: timeout, completion: completion)

        log(from: self,
            "will add \(handle) - "
                + "task: \(T.self), "
                + "with interval: \(String(describing: interval)), "
                + "on queue: \(completionQueue?.label as Any)",
            tags: TaskManager.kClrTags)

        // Fire off a closure to set up the data in the handle. Everything is going to take place on the
        // taskQueue from now onwards. We cannot add the handle to the list of pending tasks here because all access
        // to pending tasks has to be thread safe.
        self.taskQueue.async {
            // Setup the intercept callback for this task. We just wrap it and pass it through to the interceptor manager
            let intercept: Handle.Data.Interceptor = { [weak self, weak task, weak handle] completion in
                guard let strongSelf = self, var task = task, let handle = handle else {
                    completion(.ignore)
                    return
                }
                strongSelf.interceptorManager.intercept(task: &task, for: handle) { completion($0) }
            }

            let data = Handle.Data(
                operation: operation,
                taskReference: task,
                completionErrorCallback: { completion?(.failure($0)) },
                taskDidCancelCallback: { [weak task] in task?.didCancel(with: $0) },
                intercept: intercept,
                completionQueue: completionQueue
            )

            // This should be the only place in this file (other than in the data function) where this collection
            // is accessed.
            self.pendingTasks[handle] = data
            log(from: self, "did add \(handle)", tags: TaskManager.kTkQTags)

            if startImmediately {
                self.startTask(for: handle, with: data, after: interval)
            }
        }

        // There's a point in time where the handle is returned to the user and the handle has yet to be added to
        // the collection of pendingTasks. At this point, in theory, the client can call a function on the handle
        // and the handle will have no data associated with it yet.
        // This should never happen in theory because `taskQueue` is a serial queue, so the block above will have
        // been added to be executed before a client can call anything on the handle.
        return handle
    }

    private func createAsyncOperationForHandle<T: Task>(
        _ handle: TaskManager.Handle,
        task: T,
        timeout: DispatchTimeInterval?,
        completion: T.CompletionCallback?
    ) -> AsyncOperation {
        return AsyncOperation { [weak self, weak task, weak handle] operation in

            var shouldFinish = true
            defer {
                // If an error occured we mark the operaton finished
                if shouldFinish {
                    operation.finish()
                }
            }

            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self) manager dead", tags: TaskManager.kOpQTags)
                return
            }

            guard let handle = handle else {
                log(level: .verbose, from: self, "\(T.self) handle dead", tags: TaskManager.kOpQTags)
                return
            }

            guard let task = task else {
                log(level: .verbose, from: self, "\(handle) task dead", tags: TaskManager.kOpQTags)
                return
            }

            guard !operation.isCancelled else {
                log(level: .verbose, from: self, "\(handle) operation cancelled", tags: TaskManager.kOpQTags)
                return
            }

            shouldFinish = false

            strongSelf.taskQueue.sync {
                strongSelf.data(for: handle)?.state = .executing
            }

            // Make sure we prefer the explicit timeout over the configured task timeout
            strongSelf.executeAsyncOperation(operation, task: task, handle: handle, timeout: timeout ?? task.timeout, completion: completion)
        }
    }

    private func executeAsyncOperation<T: Task>(
        _ operation: AsyncOperation,
        task: T,
        handle: Handle,
        timeout: DispatchTimeInterval?,
        completion: T.CompletionCallback?
    ) {
        let timeoutWorkItem: DispatchWorkItem?
        if let timeout = timeout {
            timeoutWorkItem = self.launchTimeoutWork(for: handle, withTimeout: timeout)
        } else {
            timeoutWorkItem = nil
        }

        log(from: self, "will execute \(handle) with timeout \(String(describing: timeout))", tags: TaskManager.kOpQTags)

        // Considered putting a DispatchGroup here to signify when "only" the execute part of a Task is over,
        // but, because the API for DispatchGroup *requires* that every enter() MUST have a leave(), capturing
        // self weakly would not be an option. So we go for a less accurate version of all Task.execute being
        // run and use the operation queue's wait instead.
        task.execute { [weak self, weak task, weak handle] result in

            var shouldFinish = true
            defer {
                // Only if an error or something occured should we make the operaton finished
                if shouldFinish {
                    operation.finish()
                }
            }

            timeoutWorkItem?.cancel()

            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self) manager dead", tags: TaskManager.kClrTags)
                return
            }

            guard let handle = handle else {
                log(level: .verbose, from: strongSelf, "\(T.self) handle dead", tags: TaskManager.kClrTags)
                return
            }

            guard let task = task else {
                log(level: .verbose, from: self, "\(handle) task dead", tags: TaskManager.kClrTags)
                return
            }

            guard !operation.isCancelled else {
                log(level: .verbose, from: self, "\(handle) operation cancelled", tags: TaskManager.kClrTags)
                return
            }

            shouldFinish = false

            log(from: strongSelf, "did execute \(handle)", tags: TaskManager.kClrTags)

            strongSelf.finishExecutingTask(
                task,
                handle: handle,
                operation: operation,
                result: result,
                completion: completion
            )
        }
    }

    private func finishExecutingTask<T: Task>(
        _ task: T,
        handle: Handle,
        operation: AsyncOperation,
        result: T.Result,
        completion: T.CompletionCallback?
    ) {
        // Now we are really finished no matter what. This Operation should be removed from the OperationQueue
        operation.finish()

        // Get on to the task queue since we were previously on whichever thread Task.execute was on.
        self.taskQueue.async { [weak self, weak task, weak handle] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self).execute => manager dead", tags: TaskManager.kTkQTags)
                return
            }

            guard let handle = handle else {
                log(level: .verbose, from: strongSelf, "\(T.self).execute => handle dead", tags: TaskManager.kTkQTags)
                return
            }

            guard let task = task else {
                log(level: .verbose, from: strongSelf, "task.execute => task for \(handle) dead", tags: TaskManager.kTkQTags)
                return
            }

            // Now check if we need to execute any of the reactors. If we do and the reactor is configured
            // to requeue the task then we are done here. Else we fire up the reactors and finish the task
            let reactionData = strongSelf
                .reactors
                .enumerated()
                .reduce((indicesToRun: [Int](), requeueTask: false, suspendQueue: false)) { memo, pair in
                    let index = pair.offset
                    let reactor = pair.element
                    var indices = memo.indicesToRun
                    var requeueTask = memo.requeueTask
                    var suspendQueue = memo.suspendQueue
                    if reactor.shouldExecute(after: result, from: task, with: handle) {
                        indices.append(index)
                        // If any of the reactors say we need to requeue, then we need to requeue
                        requeueTask = memo.requeueTask || reactor.configuration.requeuesTask

                        // If any of the reactors say we need to suspent, then we need to suspend
                        suspendQueue = memo.suspendQueue || reactor.configuration.suspendsTaskQueue
                    }
                    return (indices, requeueTask, suspendQueue)
                }

            // If we have any reactors to run, let's run them
            if reactionData.indicesToRun.count > 0 {
                log(from: strongSelf,
                    "\(handle) launching reactors \(reactionData.indicesToRun) - "
                        + "after result \(result), "
                        + "requeue: \(reactionData.requeueTask), "
                        + "suspend: \(reactionData.suspendQueue)",
                    tags: TaskManager.kTkQTags)

                strongSelf.launchReactors(
                    withIndices: reactionData.indicesToRun,
                    on: handle,
                    requeueTask: reactionData.requeueTask,
                    suspendQueue: reactionData.suspendQueue
                )

                // The launchReactors function will requeue the task, so we just return now.
                if reactionData.requeueTask {
                    return
                }
            } else {
                log(level: .debug, from: strongSelf, "\(handle) caused no reactions", tags: TaskManager.kTkQTags)
            }

            // And the task is officiall done! Sanity check one more time for a cancelled task, and finish things off by
            // removing the handle form the list of pending tasks

            guard !operation.isCancelled else {
                log(level: .verbose, from: strongSelf, "task.execute => operation for \(handle) dead or cancelled", tags: TaskManager.kTkQTags)
                return
            }

            log(level: .verbose, from: strongSelf, "will finish \(handle)", tags: TaskManager.kTkQTags)
            if let data = strongSelf.data(for: handle, remove: true) {
                assert(data.operation === operation)
                data.state = .finished
                log(level: .verbose, from: strongSelf, "did finish \(handle)", tags: TaskManager.kTkQTags)
                (data.completionQueue ?? strongSelf.taskQueue).async {
                    completion?(result)
                }
            } else {
                // Even though operation.isCancelled returned false, in theory, the task could've already been cancelled
                // in a number of ways:
                // * User called handle.cancel (but then the handle should've been dead 🤔)
                // * Task timeout (but then the handle should've been dead 🤔)
                // * A reactor on the task failed (head hurt to think 🤯)
                // * A reactor on the task timeout (head hurt to think 🤯)
                log(level: .verbose, from: strongSelf, "did not finish \(handle)", tags: TaskManager.kTkQTags)
            }
        }
    }

    /**
     Blocks until all tasks finish executing
     */
    public func waitTillAllTasksFinished() {
        log(level: .verbose, from: self, "begin waiting")
        self.operationQueue.waitUntilAllOperationsAreFinished()
        log(level: .verbose, from: self, "end waiting")
    }

    private func data(for handle: Handle, remove: Bool = false) -> Handle.Data? {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        if remove {
            return self.pendingTasks.removeValue(forKey: handle)
        } else {
            return self.pendingTasks[handle]
        }
    }

    private func queueOperation(_ operation: AsyncOperation, for handle: Handle) {
        // Accessing Tasker.Operation so better be on task queue
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        self.operationQueue.addOperation(operation)
        operation.markReady()
        log(level: .verbose, from: self, "did queue \(handle)", tags: TaskManager.kTkQTags)
    }

    private func interceptAndQueue(for handle: Handle, with data: Handle.Data) {
        // Getting the raw TaskData here so we better be on the taskQueue
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.taskQueue)
            #endif
        }
        guard self.interceptorManager.count > 0 else {
            self.queueOperation(data.operation, for: handle)
            return
        }
        // This calls the closure setup in Tasker.add, which has the InterceptorManager do that actual
        // work, ascynchronously.
        data.intercept { [weak self, weak handle] result in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kClrTags)
                return
            }
            guard let handle = handle else {
                log(level: .verbose, from: self, "handle dead", tags: TaskManager.kClrTags)
                return
            }

            switch result {
            case .ignore:
                log(level: .verbose, from: self, "will not queue \(handle)")
            case let .execute(handles):
                // Queue up all the handles that are to be executed
                strongSelf.taskQueue.async {
                    guard let strongSelf = self else {
                        log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                        return
                    }
                    for handle in handles {
                        guard let data = strongSelf.data(for: handle) else {
                            continue
                        }
                        strongSelf.queueOperation(data.operation, for: handle)
                    }
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
        log(level: .verbose, from: self, "will queue \(handle)", tags: TaskManager.kTkQTags)
        guard let interval = interval else {
            self.interceptAndQueue(for: handle, with: data)
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
            strongSelf.interceptAndQueue(for: handle, with: data)
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

    private func launchReactors(withIndices reactorIndices: [Int], on finishedHandle: Handle, requeueTask: Bool, suspendQueue: Bool) {
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

        if requeueTask {
            log(from: self, "saving \(finishedHandle) to requeue list", tags: TaskManager.kTkQTags)
            self.tasksToRequeue.insert(finishedHandle)

            // Associate this handle with the reactors only if it's supposed to be requeued
            for index in reactorIndices {
                self.reactorAssoiciatedHandles[index] = self.reactorAssoiciatedHandles[index] ?? Set<Handle>()
                self.reactorAssoiciatedHandles[index]?.insert(finishedHandle)
            }
        }

        // No need to run executors that are already executing
        let nonExecutingReactors = Set(reactorIndices).subtracting(self.executingReactors)
        guard nonExecutingReactors.count > 0 else {
            log(from: self, "already executing \(self.executingReactors)", tags: TaskManager.kTkQTags)
            return
        }

        if suspendQueue {
            log(from: self, "suspending task queue", tags: TaskManager.kTkQTags)
            self.operationQueue.isSuspended = true
        }

        for index in nonExecutingReactors {
            let reactor = self.reactors[index]
            var maybeTimeoutWorkItem: DispatchWorkItem?
            var reactorWorkItem: DispatchWorkItem!

            reactorWorkItem = DispatchWorkItem { [weak self] in
                guard let strongSelf = self else {
                    log(level: .verbose, from: self, "manager dead", tags: TaskManager.kReQTags)
                    return
                }

                log(from: strongSelf, "will execute reactor \(index): \(reactor.self)", tags: TaskManager.kReQTags)

                reactor.execute { maybeError in

                    maybeTimeoutWorkItem?.cancel()

                    guard let strongSelf = self else {
                        log(level: .verbose, from: self, "manager dead", tags: TaskManager.kClrTags)
                        return
                    }

                    guard !reactorWorkItem.isCancelled else {
                        log(level: .verbose, from: strongSelf, "reactor \(index) cancelled", tags: TaskManager.kClrTags)
                        return
                    }

                    log(from: strongSelf, "did execute reactor \(index)", tags: TaskManager.kClrTags)

                    // Get off of whichever queue reactor execute completed on
                    strongSelf.taskQueue.async {
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

            self.executingReactors.insert(index)
            self.reactorQueue.async(execute: reactorWorkItem)

            // Give the async interceptor operation a timeout to complete
            if let timeout = reactor.configuration.timeout {
                let timeoutWorkItem = DispatchWorkItem { [weak self] in

                    guard let strongSelf = self else {
                        log(level: .verbose, from: self, "manager dead", tags: TaskManager.kReQTags)
                        return
                    }

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
                self.reactorQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
            }
        }

        // If we only had immediate reactors make sure queue is suspended and requeue tasks
        if self.executingReactors.count == 0 {
            log(from: self, "unsuspending task queue", tags: TaskManager.kTkQTags)
            self.operationQueue.isSuspended = false
            self.requeueTasks()
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
                data.operation = AsyncOperation(executor: data.operation.executor)
                self.queueOperation(data.operation, for: handle)
            }
        }
        self.tasksToRequeue = Set<Handle>()
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
            self.operationQueue.isSuspended = false
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

    //
    // The following are internal because they are used by TaskHandle to proxy the handle
    // to the TaskManager and then dealt with
    //

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
        let result = self.taskQueue.sync { () -> (state: TaskState, cancelled: Bool) in
            guard let data = self.data(for: handle) else {
                log(level: .verbose, from: self, "\(handle) not found", tags: TaskManager.kTkQTags)
                return (.finished, false)
            }
            let cancelled = data.operation.isCancelled
            log(from: self, "\(handle) is \(data.state), cancelled is \(cancelled)", tags: TaskManager.kTkQTags)
            return (data.state, cancelled)
        }

        if result.cancelled {
            return .finished
        } else {
            return result.state
        }
    }
}
