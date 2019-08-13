import Foundation

/**
 A task manager can be given an arbitrary number of `Task`s and initialized with a set of `Interceptor`s
 and `Reactor`s, after which it will take care of asynchonous task management for you.
 */
public class TaskManager {
    /**
     Shared TaskManager that is default constructed and has no `Interceptor`s or `Reactor`s.
     */
    public static let shared = TaskManager()

    private static let kOpQTags = [LogTags.onOperationQueue]
    private static let kTkQTags = [LogTags.onTaskQueue]
    private static let kClrTags = [LogTags.caller]

    private static var identifierCounter = AtomicInt()

    private var pendingTasks: [Handle: Handle.Data] = [:]
    private let operationQueue = OperationQueue()

    private let taskQueue = DispatchQueue(label: "Tasker.TaskManager.tasks")

    private let interceptorManager: InterceptorManager
    private let reactorManager: ReactorManager

    /**
     List of reactors that this TaskManager was created with
     */
    public var reactors: [Reactor] {
        return self.reactorManager.reactors
    }

    /**
     List of interceptors that this TaskManager was created with
     */
    public var interceptors: [Interceptor] {
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
    public init(interceptors: [Interceptor] = [], reactors: [Reactor] = []) {
        self.operationQueue.isSuspended = false
        self.reactorManager = ReactorManager(reactors: reactors)
        self.interceptorManager = InterceptorManager(interceptors)
        self.identifier = type(of: self).identifierCounter.getAndIncrement()

        self.reactorManager.delegate = self
    }

    deinit {
        // TODO: go through all handles and mark operations as finished
    }

    /**
     Add a task to the manager. You may choose to start the task immediately or start it yourself via the `Handle` that
     is returned. Additionally, you can also set an interval on when to start the task but that is only valid if `startImmediately`
     is set to true

     - parameter task: the task to run
     - parameter startImmediately: set this to false if you want to explicity call start on the `Handle` that's returned
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
    ) -> Tasker.Handle {
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
            let interceptionCallback: Handle.Data.InterceptionCallback = { [weak self, weak task, weak handle] completion in
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
                interceptionCallback: interceptionCallback,
                completionQueue: completionQueue
            )

            // This should be the only place in this file (other than in the data function) where this collection
            // is accessed.
            self.pendingTasks[handle] = data
            log(from: self, "did add \(handle)", tags: TaskManager.kTkQTags)

            // TODO: handle and document what happens if startImmediately and interval conflict
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
        let operation = AsyncOperation()
        operation.execute = { [weak self, weak task, weak handle] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self) manager dead", tags: TaskManager.kOpQTags)
                return .done
            }

            guard let handle = handle else {
                log(level: .verbose, from: self, "\(T.self) handle dead", tags: TaskManager.kOpQTags)
                return .done
            }

            guard let task = task else {
                log(level: .verbose, from: self, "\(handle) task dead", tags: TaskManager.kOpQTags)
                return .done
            }

            let maybeOperation = strongSelf.taskQueue.sync { () -> AsyncOperation? in
                guard let data = strongSelf.data(for: handle), !data.operation.isCancelled else {
                    return nil
                }
                data.state = .executing
                log(level: .verbose, from: self, "\(handle) state set to executing")
                return data.operation
            }

            guard let operation = maybeOperation else {
                log(level: .verbose, from: self, "\(handle) operation cancelled", tags: TaskManager.kOpQTags)
                return .done
            }

            // Make sure we prefer the explicit timeout over the configured task timeout
            strongSelf.executeAsyncOperation(
                operation,
                task: task,
                handle: handle,
                timeout: timeout ?? task.timeout,
                completion: completion
            )

            return .running
        }
        return operation
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

            // TODO: if task.execute switches threads, this could be racey since it's accessed on taskQueue
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
        result taskResult: T.Result,
        completion: T.CompletionCallback?
    ) {
        // Now we are really finished no matter what. This Operation should be removed from the OperationQueue
        operation.finish()

        self.reactorManager.react(task: task, result: taskResult, handle: handle) { [weak self] reactResult in

            if reactResult.suspendQueue {
                self?.operationQueue.isSuspended = true
            }

            if reactResult.requeueTask {
                return
            }

            // And the task is officially done! Sanity check one more time for a cancelled task, and finish things off by
            // removing the handle form the list of pending tasks
            self?.taskQueue.async {
                guard let strongSelf = self else {
                    log(level: .verbose, from: self, "\(T.self) manager dead", tags: TaskManager.kClrTags)
                    return
                }

                guard !operation.isCancelled else {
                    log(level: .verbose, from: self, "operation for \(handle) cancelled", tags: TaskManager.kTkQTags)
                    return
                }

                log(level: .verbose, from: self, "will finish \(handle)", tags: TaskManager.kTkQTags)
                if let data = strongSelf.data(for: handle, remove: true) {
                    assert(data.operation === operation)
                    data.state = .finished
                    log(level: .verbose, from: self, "did finish \(handle)", tags: TaskManager.kTkQTags)
                    (data.completionQueue ?? strongSelf.taskQueue).async {
                        completion?(taskResult)
                    }
                } else {
                    // Even though operation.isCancelled returned false, in theory, the task could've already been cancelled
                    // in a number of ways:
                    // * User called handle.cancel (but then the handle should've been dead 🤔)
                    // * Task timeout (but then the handle should've been dead 🤔)
                    // * A reactor on the task failed (head hurt to think 🤯)
                    // * A reactor on the task timeout (head hurt to think 🤯)
                    log(level: .verbose, from: self, "did not finish \(handle)", tags: TaskManager.kTkQTags)
                }
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
        data.interceptionCallback { [weak self, weak handle] result in
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
            // TODO: accessing timeoutWorkItem is currently, I think, not thread safe, use Atomic?
            guard !timeoutWorkItem.isCancelled else {
                log(level: .verbose, from: self, "\(handle) timeoutWorkItem cancelled", tags: TaskManager.kTkQTags)
                return
            }
            self?.removeAndCancel(handle: handle, with: .timedOut)
        }
        self.taskQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
        return timeoutWorkItem
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
    // The following are internal because they are used by TaskManager.Handle to proxy the handle
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
            log(level: .verbose, from: self, "\(handle) state is \(data.state), cancelled is \(cancelled)", tags: TaskManager.kTkQTags)
            return (data.state, cancelled)
        }

        if result.cancelled {
            return .finished
        } else {
            return result.state
        }
    }
}

extension TaskManager: ReactorManagerDelegate {
    func reactorsCompleted(handlesToRequeue: [TaskManager.Handle: ReactorManager.RequeueData]) {
        self.taskQueue.async {
            for handle in handlesToRequeue {
                if let data = self.data(for: handle.key) {
                    log(from: self, "requeueing \(handle)", tags: TaskManager.kTkQTags)
                    let newOperation = AsyncOperation()
                    newOperation.execute = data.operation.execute
                    data.operation = newOperation
                    if handle.value.reintercept {
                        self.interceptAndQueue(for: handle.key, with: data)
                    } else {
                        self.queueOperation(newOperation, for: handle.key)
                    }
                }
            }
        }
        self.operationQueue.isSuspended = false
    }

    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError) {
        self.taskQueue.async {
            var allTheData: [TaskManager.Handle.Data] = []
            for handle in associatedHandles {
                if let data = self.data(for: handle, remove: true) {
                    data.operation.cancel()
                    data.taskDidCancelCallback(error)
                    allTheData.append(data)
                }
            }

            for data in allTheData {
                (data.completionQueue ?? self.taskQueue).async {
                    data.completionErrorCallback(error)
                }
            }
        }
    }
}
