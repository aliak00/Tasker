/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

private enum InterceptTaskResult {
    case ignore
    case execute([OwnedTaskHandle])
}

private class TaskData {
    fileprivate var operation: TaskOperation
    fileprivate var anyTask: AnyTask<Any>
    fileprivate var completionErrorCallback: (TaskError) -> Void
    fileprivate var timeoutWorkItem: DispatchWorkItem?
    fileprivate var intercept: (TaskData) -> InterceptTaskResult

    init(
        operation: TaskOperation,
        anyTask: AnyTask<Any>,
        completionErrorCallback: @escaping (TaskError) -> Void,
        timeoutWorkItem: DispatchWorkItem?,
        intercept: @escaping (TaskData) -> InterceptTaskResult
    ) {
        self.operation = operation
        self.anyTask = anyTask
        self.completionErrorCallback = completionErrorCallback
        self.timeoutWorkItem = timeoutWorkItem
        self.intercept = intercept
    }
}

/**
 A task manager can be given an arbitrary number of `Task`s and initialized with a set of `TaskInterceptor`s
 and then takes care of asynchronous execution for you.
 */
public class TaskManager {

    /**
     Thes log tags can be passed to filter the logs produced by the TaskManager

     - SeeAlso `Logger'
     */
    public struct LoggerTag {
        public static let task = "tk-q"
        public static let op = "op-q"
        public static let cb = "cb"
        public static let interceptor = "in-q"
        public static let caller = "caller"
    }

    private static let kOpQTags = [LoggerTag.op]
    private static let kInQTags = [LoggerTag.interceptor]
    private static let kCbOpQTags = [LoggerTag.op, LoggerTag.cb]
    private static let kTkQTags = [LoggerTag.task]
    private static let kCbInQTags = [LoggerTag.interceptor, LoggerTag.cb]
    private static let kClrTags = [LoggerTag.caller]

    private static let logKeys: Void = {
        log("log keys = ["
            + "\(LoggerTag.task): task queue, "
            + "\(LoggerTag.op): operation queue, "
            + "\(LoggerTag.cb): callback, "
            + "\(LoggerTag.interceptor): interceptor queue, "
            + "\(LoggerTag.caller): caller thread"
            + "]"
        )
    }()

    static var counter = AtomicInt()

    private var pendingTasks: [OwnedTaskHandle: TaskData] = [:]
    private let taskOperationQueue = OperationQueue()

    private let taskQueue = DispatchQueue(label: "Swooft.Tasker.TaskManager.tasks")
    private let interceptorQueue = DispatchQueue(label: "Swooft.Tasker.TaskManager.interceptors", attributes: [.concurrent])

    private let interceptors: [TaskInterceptor]

    private var executingInterceptors = Set<Int>()
    private var interceptorAssoiciatedHandles: [Int: Set<OwnedTaskHandle>] = [:] // TODO: Can/should these handles be weak?

    private var tasksToRequeue = Set<OwnedTaskHandle>() // TODO: Can/should these handles be weak?
    private var tasksToBatch: [Int: [Weak<OwnedTaskHandle>]] = [:]

    let identifier: Int

    /**
     Initializes this manager object.

     - parameter interceptors: an array of interceptors that will be applied to every task before being started
     */
    public init(interceptors: [TaskInterceptor] = []) {
        TaskManager.logKeys
        self.taskOperationQueue.isSuspended = false
        self.interceptors = interceptors
        self.identifier = type(of: self).counter.getAndIncrement()
    }

    /**
     Add a task to the manager. You may choose to start the task immediately or start if yourself via the `TaskHandle` that
     is returned. Additionally, you can also set an interval on when to start the task but that is only valid if `startImmediately`
     is set to true

     - parameter task: the task to run
     - parameter startImmediately: set this to false if you want to call start on the `TaskHandle` that's returned
     - parameter after: set this to some value if you want the task to start running after some interval
     - parameter completionHandler: called after the task is done with the result of `Task.execute`
     */
    @discardableResult
    public func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        completionHandler: T.ResultCallback? = nil
    ) -> TaskHandle {

        let handle = OwnedTaskHandle(owner: self)

        let operation = TaskOperation { [weak self, weak task, weak handle] operation in

            guard let strongSelf = self else {
                log(from: self, "\(T.self) operation => manager dead", tags: TaskManager.kOpQTags)
                return
            }

            guard let handle = handle else {
                log(from: strongSelf, "operation => handle dead", tags: TaskManager.kOpQTags)
                return
            }

            guard let task = task else {
                log(from: strongSelf, "\(handle) operation => task dead", tags: TaskManager.kOpQTags)
                return
            }

            guard !operation.isCancelled else {
                log(from: strongSelf, "\(handle) operation => operation cancelled", tags: TaskManager.kOpQTags)
                return
            }

            strongSelf.execute(task: task, handle: handle, operation: operation, completionHandler: completionHandler)
        }

        log(from: self, "will add \(T.self) with \(handle) after interval \(String(describing: interval))", tags: TaskManager.kClrTags)

        self.taskQueue.async { [weak self] in
            guard let strongSelf = self else {
                log(from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }

            let intercept: (TaskData) -> InterceptTaskResult = { [weak task, weak handle] data in
                guard let strongSelf = self, var task = task, let handle = handle else {
                    return .ignore
                }
                return strongSelf.interceptTask(&task, handle: handle, operation: data.operation)
            }

            let data = TaskData(
                operation: operation,
                anyTask: AnyTask(task: task),
                completionErrorCallback: { completionHandler?(.failure($0)) },
                timeoutWorkItem: nil,
                intercept: intercept
            )

            strongSelf.pendingTasks[handle] = data
            log(from: strongSelf, "did add \(T.self) with \(handle)", tags: TaskManager.kTkQTags)

            if startImmediately {
                strongSelf.startTask(for: handle, with: data, after: interval)
            }
        }

        return handle
    }

    private func execute<T: Task>(task: T, handle: OwnedTaskHandle, operation: TaskOperation, completionHandler: T.ResultCallback?) {

        if let timeout = task.timeout {
            self.launchTimeoutWork(for: handle, withTimeout: timeout)
        }

        log(from: self, "will execute \(T.self) with \(handle)", tags: TaskManager.kOpQTags)

        task.execute { [weak self, weak task, weak handle, weak operation] result in

            guard let strongSelf = self else {
                log(from: self, "\(T.self) manager dead", tags: TaskManager.kCbOpQTags)
                return
            }

            guard let handle = handle else {
                log(from: strongSelf, "\(T.self) handle dead", tags: TaskManager.kCbOpQTags)
                return
            }

            log(from: strongSelf, "did execute \(T.self) with \(handle)", tags: TaskManager.kCbOpQTags)

            guard let task = task else {
                log(from: strongSelf, "\(T.self) for \(handle) dead", tags: TaskManager.kCbOpQTags)
                return
            }

            // Get off whatever thread the task called the callback on
            strongSelf.taskQueue.async { [weak handle] in
                guard let strongSelf = self else {
                    log(from: self, "\(T.self).execute => manager dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let handle = handle else {
                    log(from: strongSelf, "\(T.self).execute => handle dead", tags: TaskManager.kTkQTags)
                    return
                }

                strongSelf.pendingTasks[handle]?.timeoutWorkItem?.cancel()

                //
                // Now check if we need to execute any of the interceptors. If we do and the interceptor is configured
                // to requeue the task then we are done here. Else we fire up the interceptors and finishes the task
                //
                let interceptionData = strongSelf.interceptors.enumerated().reduce((indices: [Int](), requeueTask: false, suspendQueue: false)) { memo, pair in
                    let index = pair.offset
                    let interceptor = pair.element
                    var indices = memo.indices
                    var requeueTask = memo.requeueTask
                    var suspendQueue = memo.suspendQueue
                    if interceptor.shouldExecute(after: result, from: task, with: handle) {
                        log(from: strongSelf, "will execute \(interceptor.self) on \(handle) after \(result)", tags: TaskManager.kTkQTags)
                        indices.append(index)
                        requeueTask = memo.requeueTask || interceptor.configuration.requeuesTask
                        suspendQueue = memo.suspendQueue || interceptor.configuration.suspendsTaskQueue
                    }
                    return (indices, requeueTask, suspendQueue)
                }

                if interceptionData.indices.count > 0 {
                    strongSelf.launchInterceptors(
                        at: interceptionData.indices,
                        on: handle,
                        requeueTask: interceptionData.requeueTask,
                        suspendQueue: interceptionData.suspendQueue
                    )

                    if interceptionData.requeueTask {
                        return
                    }
                }

                guard let operation = operation, !operation.isCancelled else {
                    log(from: strongSelf, "\(T.self).execute => operation for \(handle) dead or cancelled", tags: TaskManager.kTkQTags)
                    return
                }

                if let data = strongSelf.pendingTasks.removeValue(forKey: handle) {
                    assert(data.operation === operation)
                    data.operation.markFinished()
                    log(from: strongSelf, "did finish \(T.self) with \(handle)", tags: TaskManager.kTkQTags)
                    strongSelf.taskQueue.async {
                        completionHandler?(result)
                    }
                } else {
                    log(from: strongSelf, "\(T.self) with \(handle) not found", tags: TaskManager.kTkQTags)
                }
            }
        }
    }

    private func interceptTask<T: Task>(_ task: inout T, handle: OwnedTaskHandle, operation _: TaskOperation) -> InterceptTaskResult {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        //
        // The algorithm here is as follows
        //
        // * We execute all interceptors
        // * If an interceptor says force execute then that takes precedence over everything
        // * If an interceptor says to ignore then we ignore unless it's a force execute
        // * If an interceptor has hold the task, then we hold it unless it's already held or ignored
        //
        // * If the result is go ahead with execution, then we execute everything that was on hold as well
        //
        var shouldBeIgnored = false
        var shouldBeForceExecuted = false
        var interceptorIndexHoldingTask: Int?
        var interceptorIndicesRequestingExecute: [Int] = []
        for (index, interceptor) in self.interceptors.enumerated() {
            log(from: self, "intercepting \(handle) with \(interceptor)", tags: TaskManager.kInQTags)
            switch interceptor.intercept(task: &task, currentBatchCount: self.tasksToBatch[index]?.count ?? 0) {
            case .forceExecute:
                shouldBeForceExecuted = true
                interceptorIndexHoldingTask = nil
                fallthrough
            case .execute:
                interceptorIndicesRequestingExecute.append(index)
                break
            case .ignore:
                shouldBeIgnored = true
                interceptorIndexHoldingTask = nil
            case .hold:
                if interceptorIndexHoldingTask == nil && !shouldBeForceExecuted && !shouldBeIgnored {
                    interceptorIndexHoldingTask = index
                }
            }
        }

        if shouldBeIgnored && !shouldBeForceExecuted {
            log(from: self, "ignoring \(T.self) with \(handle)", tags: TaskManager.kTkQTags)
            self.cancel(handle: handle, with: nil)
            return .ignore
        }

        if let index = interceptorIndexHoldingTask, !shouldBeForceExecuted {
            log(from: self, "holding \(T.self) with \(handle)", tags: TaskManager.kTkQTags)
            self.tasksToBatch[index] = self.tasksToBatch[index] ?? []
            self.tasksToBatch[index]?.append(Weak(handle))
            return .ignore
        }

        var batchedHandles: [OwnedTaskHandle] = []
        for index in interceptorIndicesRequestingExecute {
            for weakHandle in self.tasksToBatch[index] ?? [] {
                if let handle = weakHandle.value {
                    batchedHandles.append(handle)
                }
            }
            self.tasksToBatch[index] = nil
        }

        log(from: self, "carrying on with \(T.self) for \(handle)", tags: TaskManager.kTkQTags)

        if batchedHandles.count > 0 {
            log(from: self, "\(handle) releasing batched handles \(batchedHandles)", tags: TaskManager.kTkQTags)
        }

        let handles = batchedHandles + [handle]
        return .execute(handles)
    }

    private func startTask(for handle: OwnedTaskHandle, with data: TaskData, after interval: DispatchTimeInterval? = nil) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }

        func interceptAndStart(data: TaskData, on handle: OwnedTaskHandle, manager: TaskManager) {
            guard manager.interceptors.count > 0 else {
                log(from: self, "will start operation for \(handle)", tags: TaskManager.kTkQTags)
                manager.taskOperationQueue.addOperation(data.operation)
                return
            }
            guard case let .execute(handles) = data.intercept(data) else {
                log(from: self, "will not start operation for \(handle)", tags: TaskManager.kTkQTags)
                return
            }

            for handle in handles {
                guard let operation = manager.pendingTasks[handle]?.operation else {
                    log(from: self, "\(handle) not found", tags: TaskManager.kTkQTags)
                    continue
                }
                log(from: self, "will start operation for \(handle)", tags: TaskManager.kTkQTags)
                manager.taskOperationQueue.addOperation(operation)
            }
        }

        let closure: () -> Void = { [weak self, weak handle, weak data] in
            guard let strongSelf = self else {
                log(from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let handle = handle else {
                log(from: strongSelf, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let data = data, !data.operation.isCancelled else {
                log(from: strongSelf, "\(handle) operation dead or cancelled", tags: TaskManager.kTkQTags)
                return
            }

            interceptAndStart(data: data, on: handle, manager: strongSelf)
        }

        // TODO: Why does everything break if you move this linein to "interceptAndStart"?
        data.operation.markReady()

        if let interval = interval {
            self.taskQueue.asyncAfter(deadline: .now() + interval, execute: closure)
        } else {
            self.taskQueue.async(execute: closure)
        }
    }

    private func launchTimeoutWork(for handle: OwnedTaskHandle, withTimeout timeout: DispatchTimeInterval) {
        self.taskQueue.async { [weak self, weak handle] in
            guard let handle = handle else {
                log(from: self, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let data = self?.pendingTasks[handle] else {
                log(from: self, "\(handle) data unavailable", tags: TaskManager.kTkQTags)
                return
            }
            let timeoutWorkItem = DispatchWorkItem { [weak self, weak handle, weak data] in
                guard let handle = handle else {
                    log(from: self, "handle dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let workItem = data?.timeoutWorkItem, !workItem.isCancelled else {
                    log(from: self, "\(handle) timeoutWorkItem cancelled", tags: TaskManager.kTkQTags)
                    return
                }
                self?.removeAndCancel(handle: handle, with: .timedOut)
            }

            data.timeoutWorkItem = timeoutWorkItem
            self?.taskQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
        }
    }

    private func launchInterceptors(at indices: [Int], on finishedHandle: OwnedTaskHandle, requeueTask: Bool, suspendQueue: Bool) {
        //
        // Executing the interceptors involves the following:
        //
        // 1. Cull out interceptors that are already executing
        // 2. Note down immediate interceptors
        // 3. Queue up asynchronous interceptors
        // 4. Execute immediate interceptors
        // - If an interceptor says requeue a task, requeue
        // - If an interceptor says pause task queue, then pause
        // - When all queued interceptors are done, restart task queue, pause interceptor queue
        //
        self.taskQueue.async { [weak self, weak finishedHandle] in

            guard let strongSelf = self else {
                log(from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }

            log(from: strongSelf, "indices: \(indices), requeue: \(requeueTask), suspend: \(suspendQueue), \(finishedHandle as Any)", tags: TaskManager.kTkQTags)

            if requeueTask {
                guard let handle = finishedHandle else {
                    log(from: strongSelf, "handle dead, cannot requeue", tags: TaskManager.kTkQTags)
                    return
                }
                log(from: strongSelf, "saving \(handle) to requeue list", tags: TaskManager.kTkQTags)
                strongSelf.tasksToRequeue.insert(handle)

                // Associate this handle with the interceptors only if it's supposed to be requeued
                for index in indices {
                    strongSelf.interceptorAssoiciatedHandles[index] = strongSelf.interceptorAssoiciatedHandles[index] ?? Set<OwnedTaskHandle>()
                    strongSelf.interceptorAssoiciatedHandles[index]?.insert(handle)
                }
            }

            // No need to run executors that are already executing
            let interceptorIndices = Set(indices).subtracting(strongSelf.executingInterceptors)
            guard interceptorIndices.count > 0 else {
                log(from: strongSelf, "already executing \(strongSelf.executingInterceptors)", tags: TaskManager.kTkQTags)
                return
            }

            if suspendQueue {
                log(from: strongSelf, "suspending task queue", tags: TaskManager.kTkQTags)
                strongSelf.taskOperationQueue.isSuspended = true
            }

            var immediateInterceptorIndices = Set<Int>()

            for index in interceptorIndices {
                let interceptor = strongSelf.interceptors[index]

                // If interceptor is immediate than mark it and move on
                if interceptor.configuration.isImmediate {
                    log(from: strongSelf, "adding immediate interceptor \(interceptor.self)", tags: TaskManager.kTkQTags)
                    immediateInterceptorIndices.insert(index)
                    continue
                }

                var maybeTimeoutWorkItem: DispatchWorkItem?
                var interceptorWorkItem: DispatchWorkItem!

                interceptorWorkItem = DispatchWorkItem { [weak self] in
                    guard let strongSelf = self else {
                        log(from: self, "manager dead", tags: TaskManager.kInQTags)
                        return
                    }

                    log(from: strongSelf, "executing interceptor \(interceptor.self)", tags: TaskManager.kInQTags)

                    interceptor.execute { [weak self] maybeError in

                        maybeTimeoutWorkItem?.cancel()

                        guard let strongSelf = self else {
                            log(from: self, "manager dead", tags: TaskManager.kCbInQTags)
                            return
                        }

                        guard !interceptorWorkItem.isCancelled else {
                            log(from: strongSelf, "\(interceptor.self) cancelled", tags: TaskManager.kCbInQTags)
                            return
                        }

                        log(from: strongSelf, "executed interceptor \(interceptor.self)", tags: TaskManager.kCbInQTags)

                        // Get off of whichever queue interceptor execute completed on
                        strongSelf.taskQueue.async { [weak self] in
                            guard let strongSelf = self else {
                                log(from: self, "manager dead", tags: TaskManager.kTkQTags)
                                return
                            }

                            log(from: strongSelf, "removing queued interceptor \(interceptor.self)", tags: TaskManager.kTkQTags)

                            if let error = maybeError {
                                strongSelf.cancelAssociatedTasksForInterceptor(at: index, with: .interceptorFailed(error))
                            }

                            strongSelf.removeInterceptor(at: index)
                        }
                    }
                }

                strongSelf.executingInterceptors.insert(index)
                strongSelf.interceptorQueue.async(execute: interceptorWorkItem)

                // Give the async interceptor operation a timeout to complete
                if let timeout = interceptor.configuration.timeout {
                    let timeoutWorkItem = DispatchWorkItem { [weak self] in

                        strongSelf.taskQueue.async {

                            interceptorWorkItem.cancel()

                            guard let timeoutWorkItem = maybeTimeoutWorkItem, !timeoutWorkItem.isCancelled else {
                                log(from: self, "\(interceptor.self) timeout work cancelled", tags: TaskManager.kTkQTags)
                                return
                            }

                            guard let strongSelf = self else {
                                log(from: self, "manager dead", tags: TaskManager.kInQTags)
                                return
                            }

                            log(from: strongSelf, "interceptor \(interceptor.self) timed out", tags: TaskManager.kTkQTags)

                            strongSelf.taskQueue.async {
                                strongSelf.cancelAssociatedTasksForInterceptor(at: index, with: .interceptorTimedOut("\(interceptor)"))
                                strongSelf.removeInterceptor(at: index)
                            }
                        }
                    }

                    maybeTimeoutWorkItem = timeoutWorkItem
                    strongSelf.interceptorQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
                }
            }

            strongSelf.interceptorQueue.sync {
                strongSelf.executeImmediateInterceptors(at: Array(immediateInterceptorIndices))
            }

            // If we only had immediate interceptors make sure queue is suspended and requeue tasks
            if strongSelf.executingInterceptors.count == 0 {
                log(from: strongSelf, "unsuspending task queue", tags: TaskManager.kTkQTags)
                strongSelf.taskOperationQueue.isSuspended = false
                strongSelf.requeueTasks()
            }
        }
    }

    private func requeueTasks() {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        for handle in self.tasksToRequeue {
            if let data = self.pendingTasks[handle] {
                log(from: self, "requeueing \(handle)", tags: TaskManager.kTkQTags)
                data.operation.markFinished()
                data.operation = TaskOperation(executor: data.operation.executor)
                data.operation.markReady()
                self.startTask(for: handle, with: data)
            }
        }
        self.tasksToRequeue = Set<OwnedTaskHandle>()
    }

    private func executeImmediateInterceptors(at indicies: [Int]) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.interceptorQueue)
        }
        DispatchQueue.concurrentPerform(iterations: indicies.count) { index in
            let semaphore = DispatchSemaphore(value: 0)
            let interceptor = self.interceptors[index]
            log(from: self, "executing immediate interceptor \(interceptor.self)", tags: TaskManager.kInQTags)
            var maybeError: TaskError?
            interceptor.execute { error in
                if let error = error {
                    maybeError = .interceptorFailed(error)
                }
                semaphore.signal()
            }
            if let timeout = interceptor.configuration.timeout, semaphore.wait(timeout: .now() + timeout) == .timedOut {
                maybeError = .interceptorTimedOut("\(interceptor)")
            } else {
                semaphore.wait()
            }
            guard let error = maybeError else {
                log(from: self, "executed immediate interceptor \(interceptor.self)", tags: TaskManager.kInQTags)
                return
            }
            log(from: self, "immediate interceptor \(interceptor.self) failed with: \(error)", tags: TaskManager.kInQTags)
            self.taskQueue.async { [weak self] in
                self?.cancelAssociatedTasksForInterceptor(at: index, with: .interceptorFailed(error))
            }
        }
    }

    private func cancelAssociatedTasksForInterceptor(at index: Int, with error: TaskError) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        var allTheData: [TaskData] = []
        for handle in self.interceptorAssoiciatedHandles[index] ?? Set<OwnedTaskHandle>() {
            if let data = self.pendingTasks.removeValue(forKey: handle) {
                log(from: self, "removed handle \(handle) for interceptor \(index)", tags: TaskManager.kTkQTags)
                data.operation.cancel()
                data.anyTask.didCancel(with: error)
                allTheData.append(data)
                if self.tasksToRequeue.remove(handle) != nil {
                    log(from: self, "removing \(handle) from requeue list", tags: TaskManager.kTkQTags)
                }
            }
        }
        self.interceptorAssoiciatedHandles[index]?.removeAll()
        self.taskQueue.async {
            for data in allTheData {
                data.completionErrorCallback(error)
            }
        }
    }

    private func removeInterceptor(at index: Int) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        self.executingInterceptors.remove(index)
        if self.executingInterceptors.count == 0 {
            // Stop interceptor queue and ensure task queue is not suspended
            self.taskOperationQueue.isSuspended = false
            self.requeueTasks()
        }
    }

    private func removeAndCancel(handle: OwnedTaskHandle, with error: TaskError?) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        guard let data = self.pendingTasks.removeValue(forKey: handle) else {
            log(from: self, "\(handle) already removed", tags: TaskManager.kTkQTags)
            return
        }
        data.operation.cancel()
        log(from: self, "removed \(handle) with error \(error as Any)", tags: TaskManager.kTkQTags)
        guard let error = error else {
            return
        }
        data.anyTask.didCancel(with: error)
        self.taskQueue.async {
            data.completionErrorCallback(error)
        }
    }

    func cancel(handle: OwnedTaskHandle, with error: TaskError?) {
        log(from: self, "will cancel \(handle)", tags: TaskManager.kClrTags)
        self.taskQueue.async { [weak self, weak handle] in
            guard let strongSelf = self else {
                log(from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let handle = handle else {
                log(from: strongSelf, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            strongSelf.removeAndCancel(handle: handle, with: error)
        }
    }

    func start(handle: OwnedTaskHandle) {
        self.taskQueue.async { [weak self, weak handle] in
            guard let strongSelf = self else {
                log(from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }
            guard let handle = handle else {
                log(from: strongSelf, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            if let data = strongSelf.pendingTasks[handle] {
                strongSelf.startTask(for: handle, with: data)
            }
        }
    }

    func taskState(for handle: OwnedTaskHandle) -> TaskState {
        let maybeOperation = self.taskQueue.sync { () -> TaskOperation? in
            guard let data = self.pendingTasks[handle] else {
                log(from: self, "\(handle) not found", tags: TaskManager.kTkQTags)
                return nil
            }
            log(from: self, "\(handle) operation  is \(data.operation.state)", tags: TaskManager.kTkQTags)
            return data.operation
        }
        guard let operation = maybeOperation else {
            return .finished
        }
        switch (operation.state, operation.isCancelled) {
        case (_, true):
            return .finished
        case (.executing, _), (.ready, _):
            return .executing
        case (.finished, _):
            return .finished
        case (.pending, _):
            return .pending
        }
    }
}
