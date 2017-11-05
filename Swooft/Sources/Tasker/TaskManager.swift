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
    fileprivate let anyTask: AnyTask<Any>
    fileprivate let completionErrorCallback: (TaskError) -> Void
    fileprivate let intercept: () -> InterceptTaskResult

    init(
        operation: TaskOperation,
        anyTask: AnyTask<Any>,
        completionErrorCallback: @escaping (TaskError) -> Void,
        intercept: @escaping () -> InterceptTaskResult
    ) {
        self.operation = operation
        self.anyTask = anyTask
        self.completionErrorCallback = completionErrorCallback
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
        public static let task = "tq"
        public static let op = "oq"
        public static let cb = "cb"
        public static let interceptor = "iq"
        public static let reactor = "rq"
        public static let caller = "caller"
    }

    private static let kOpQTags = [LoggerTag.op]
    private static let kInQTags = [LoggerTag.interceptor]
    private static let kCbOpQTags = [LoggerTag.op, LoggerTag.cb]
    private static let kTkQTags = [LoggerTag.task]
    private static let kCbReQTags = [LoggerTag.reactor, LoggerTag.cb]
    private static let kClrTags = [LoggerTag.caller]
    private static let kReQTags = [LoggerTag.reactor]

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
    private let reactorQueue = DispatchQueue(label: "Swooft.Tasker.TaskManager.reactors", attributes: [.concurrent])
    private let interceptorQueue = DispatchQueue(label: "Swooft.Tasker.TaskManager.reactors")

    private let interceptors: [TaskInterceptor]
    private let reactors: [TaskReactor]

    private var executingReactors = Set<Int>()
    private var reactorAssoiciatedHandles: [Int: Set<OwnedTaskHandle>] = [:] // TODO: Can/should these handles be weak?

    private var tasksToRequeue = Set<OwnedTaskHandle>() // TODO: Can/should these handles be weak?
    private var tasksToBatch: [Int: [Weak<OwnedTaskHandle>]] = [:]

    let identifier: Int

    /**
     Initializes this manager object.

     - parameter interceptors: an array of interceptors that will be applied to every task before being started
     - parameter reactors: an array of reactors that will be applied to every task after it's executed
     */
    public init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = []) {
        TaskManager.logKeys
        self.taskOperationQueue.isSuspended = false
        self.interceptors = interceptors
        self.reactors = reactors
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

            strongSelf.execute(task: task, handle: handle, operation: operation, completionHandler: completionHandler)
        }

        log(from: self, "will add \(handle) - task: \(T.self), interval: \(String(describing: interval))", tags: TaskManager.kClrTags)

        self.taskQueue.async { [weak self] in
            guard let strongSelf = self else {
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }

            let intercept: () -> InterceptTaskResult = { [weak task, weak handle] in
                guard let strongSelf = self, var task = task, let handle = handle else {
                    return .ignore
                }
                return strongSelf.interceptTask(&task, handle: handle)
            }

            let data = TaskData(
                operation: operation,
                anyTask: AnyTask(task: task),
                completionErrorCallback: { completionHandler?(.failure($0)) },
                intercept: intercept
            )

            strongSelf.pendingTasks[handle] = data
            log(from: self, "did add \(handle)", tags: TaskManager.kTkQTags)

            if startImmediately {
                strongSelf.startTask(for: handle, with: data, after: interval)
            }
        }

        return handle
    }

    private func execute<T: Task>(task: T, handle: OwnedTaskHandle, operation: TaskOperation, completionHandler: T.ResultCallback?) {

        let timeoutWorkItem: DispatchWorkItem?
        if let timeout = task.timeout {
            timeoutWorkItem = self.launchTimeoutWork(for: handle, withTimeout: timeout)
        } else {
            timeoutWorkItem = nil
        }

        log(from: self, "will execute \(handle)", tags: TaskManager.kOpQTags)

        task.execute { [weak self, weak task, weak handle, weak operation] result in

            timeoutWorkItem?.cancel()

            guard let strongSelf = self else {
                log(level: .verbose, from: self, "\(T.self).execute manager dead", tags: TaskManager.kCbOpQTags)
                return
            }

            guard let handle = handle else {
                log(level: .verbose, from: strongSelf, "\(T.self).execute handle dead", tags: TaskManager.kCbOpQTags)
                return
            }

            log(from: strongSelf, "did execute \(handle)", tags: TaskManager.kCbOpQTags)

            // Get off whatever thread the task called the callback on
            strongSelf.taskQueue.async { [weak handle] in
                guard let strongSelf = self else {
                    log(level: .verbose, from: self, "\(T.self).execute => manager dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let handle = handle else {
                    log(level: .verbose, from: strongSelf, "\(T.self).execute => handle dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let task = task else {
                    log(level: .verbose, from: strongSelf, "\task.execute => task for \(handle) dead", tags: TaskManager.kCbOpQTags)
                    return
                }

                //
                // Now check if we need to execute any of the interceptors. If we do and the interceptor is configured
                // to requeue the task then we are done here. Else we fire up the interceptors and finishes the task
                //
                let reactionData = strongSelf.reactors.enumerated().reduce((indices: [Int](), requeueTask: false, suspendQueue: false)) { memo, pair in
                    let index = pair.offset
                    let reactor = pair.element
                    var indices = memo.indices
                    var requeueTask = memo.requeueTask
                    var suspendQueue = memo.suspendQueue
                    if reactor.shouldExecute(after: result, from: task, with: handle) {
                        log(from: strongSelf, "will execute \(reactor.self) on \(handle) after \(result)", tags: TaskManager.kTkQTags)
                        indices.append(index)
                        requeueTask = memo.requeueTask || reactor.configuration.requeuesTask
                        suspendQueue = memo.suspendQueue || reactor.configuration.suspendsTaskQueue
                    }
                    return (indices, requeueTask, suspendQueue)
                }

                if reactionData.indices.count > 0 {
                    strongSelf.launchReactors(
                        at: reactionData.indices,
                        on: handle,
                        requeueTask: reactionData.requeueTask,
                        suspendQueue: reactionData.suspendQueue
                    )

                    if reactionData.requeueTask {
                        return
                    }
                }

                guard let operation = operation, !operation.isCancelled else {
                    log(level: .verbose, from: strongSelf, "\(T.self).execute => operation for \(handle) dead or cancelled", tags: TaskManager.kTkQTags)
                    return
                }

                log(from: strongSelf, "will finish \(handle)", tags: TaskManager.kTkQTags)
                if let data = strongSelf.data(for: handle, remove: true) {
                    assert(data.operation === operation)
                    data.operation.markFinished()
                    log(from: strongSelf, "did finish \(handle)", tags: TaskManager.kTkQTags)
                    strongSelf.taskQueue.async {
                        completionHandler?(result)
                    }
                } else {
                    log(from: strongSelf, "did not finish \(handle)", tags: TaskManager.kTkQTags)
                }
            }
        }
    }

    private func interceptTask<T: Task>(_ task: inout T, handle: OwnedTaskHandle) -> InterceptTaskResult {
        // Calling an interceptor so we better be on the interceptor queue
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.interceptorQueue)
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
            case .discard:
                shouldBeIgnored = true
                interceptorIndexHoldingTask = nil
            case .hold:
                if interceptorIndexHoldingTask == nil && !shouldBeForceExecuted && !shouldBeIgnored {
                    interceptorIndexHoldingTask = index
                }
            }
        }

        if shouldBeIgnored && !shouldBeForceExecuted {
            log(from: self, "discarding \(T.self) for \(handle)", tags: TaskManager.kTkQTags)
            self.cancel(handle: handle, with: nil)
            return .ignore
        }

        if let index = interceptorIndexHoldingTask, !shouldBeForceExecuted {
            log(from: self, "holding \(T.self) for \(handle)", tags: TaskManager.kTkQTags)
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

    private func data(for handle: OwnedTaskHandle, remove: Bool = false) -> TaskData? {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
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

    private func startTask(for handle: OwnedTaskHandle, with data: TaskData, after interval: DispatchTimeInterval? = nil) {
        // Getting the raw TaskData here so we better be on the taskQueue
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }

        guard self.interceptors.count > 0 else {
            log(from: self, "will queue \(handle)", tags: TaskManager.kTkQTags)
            let addOperation = { [weak self, weak handle] in
                guard let strongSelf = self else {
                    log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let handle = handle else {
                    log(level: .verbose, from: self, "handle dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let data = strongSelf.data(for: handle) else {
                    log(level: .verbose, from: self, "did not queue \(handle)", tags: TaskManager.kTkQTags)
                    return
                }
                strongSelf.taskOperationQueue.addOperation(data.operation)
                log(from: self, "did queue \(handle)", tags: TaskManager.kTkQTags)
                data.operation.markReady()
            }
            if let interval = interval {
                self.taskQueue.asyncAfter(deadline: .now() + interval, execute: addOperation)
            } else {
                self.taskQueue.async(execute: addOperation)
            }
            return
        }

        let interceptThenAdd = { [weak self, weak handle, weak data] in
            guard let strongSelf = self, let handle = handle, let data = data else {
                return
            }
            guard case let .execute(handles) = data.intercept() else {
                log(level: .verbose, from: self, "will not execute \(handle)", tags: TaskManager.kInQTags)
                return
            }

            for handle in handles {
                log(from: self, "will queue \(handle)", tags: TaskManager.kTkQTags)
                strongSelf.taskQueue.async { [weak self, weak handle] in
                    guard let handle = handle, let data = self?.data(for: handle) else {
                        return
                    }
                    self?.taskOperationQueue.addOperation(data.operation)
                    log(from: self, "did queue \(handle)", tags: TaskManager.kTkQTags)
                    data.operation.markReady()
                }
            }
        }

        log(from: self, "will intercept task for \(handle)", tags: TaskManager.kTkQTags)
        if let interval = interval {
            self.interceptorQueue.asyncAfter(deadline: .now() + interval, execute: interceptThenAdd)
        } else {
            self.interceptorQueue.async(execute: interceptThenAdd)
        }
    }

    private func launchTimeoutWork(for handle: OwnedTaskHandle, withTimeout timeout: DispatchTimeInterval) -> DispatchWorkItem? {
        var timeoutWorkItemHandle: DispatchWorkItem?
        self.taskQueue.async { [weak self, weak handle] in
            guard let handle = handle else {
                log(level: .verbose, from: self, "handle dead", tags: TaskManager.kTkQTags)
                return
            }
            let timeoutWorkItem = DispatchWorkItem { [weak self, weak handle] in
                guard let handle = handle else {
                    log(level: .verbose, from: self, "handle dead", tags: TaskManager.kTkQTags)
                    return
                }
                guard let workItem = timeoutWorkItemHandle, !workItem.isCancelled else {
                    log(from: self, "\(handle) timeoutWorkItem cancelled", tags: TaskManager.kTkQTags)
                    return
                }
                self?.removeAndCancel(handle: handle, with: .timedOut)
            }
            timeoutWorkItemHandle = timeoutWorkItem
            self?.taskQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
        }
        return timeoutWorkItemHandle
    }

    private func launchReactors (at indices: [Int], on finishedHandle: OwnedTaskHandle, requeueTask: Bool, suspendQueue: Bool) {
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
                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                return
            }

            log(from: strongSelf, "indices: \(indices), requeue: \(requeueTask), suspend: \(suspendQueue), \(finishedHandle as Any)", tags: TaskManager.kTkQTags)

            if requeueTask {
                guard let handle = finishedHandle else {
                    log(level: .verbose, from: strongSelf, "handle dead, cannot requeue", tags: TaskManager.kTkQTags)
                    return
                }
                log(from: strongSelf, "saving \(handle) to requeue list", tags: TaskManager.kTkQTags)
                strongSelf.tasksToRequeue.insert(handle)

                // Associate this handle with the interceptors only if it's supposed to be requeued
                for index in indices {
                    strongSelf.reactorAssoiciatedHandles[index] = strongSelf.reactorAssoiciatedHandles[index] ?? Set<OwnedTaskHandle>()
                    strongSelf.reactorAssoiciatedHandles[index]?.insert(handle)
                }
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

                // If interceptor is immediate than mark it and move on
                if reactor.configuration.isImmediate {
                    log(from: strongSelf, "adding immediate reactor \(reactor.self)", tags: TaskManager.kTkQTags)
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

                    log(from: strongSelf, "executing reactor \(reactor.self)", tags: TaskManager.kReQTags)

                    reactor.execute { [weak self] maybeError in

                        maybeTimeoutWorkItem?.cancel()

                        guard let strongSelf = self else {
                            log(level: .verbose, from: self, "manager dead", tags: TaskManager.kCbReQTags)
                            return
                        }

                        guard !reactorWorkItem.isCancelled else {
                            log(from: strongSelf, "\(reactor.self) cancelled", tags: TaskManager.kCbReQTags)
                            return
                        }

                        log(from: strongSelf, "executed reactor \(reactor.self)", tags: TaskManager.kCbReQTags)

                        // Get off of whichever queue reactor execute completed on
                        strongSelf.taskQueue.async { [weak self] in
                            guard let strongSelf = self else {
                                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kTkQTags)
                                return
                            }

                            log(from: strongSelf, "removing queued reactor \(reactor.self)", tags: TaskManager.kTkQTags)

                            if let error = maybeError {
                                strongSelf.cancelAssociatedTasksForReactor(at: index, with: .reactorFailed(error))
                            }

                            strongSelf.removeReactor(at: index)
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
                                log(from: self, "\(reactor.self) timeout work cancelled", tags: TaskManager.kTkQTags)
                                return
                            }

                            guard let strongSelf = self else {
                                log(level: .verbose, from: self, "manager dead", tags: TaskManager.kInQTags)
                                return
                            }

                            log(from: strongSelf, "reactor \(reactor.self) timed out", tags: TaskManager.kTkQTags)

                            strongSelf.taskQueue.async {
                                strongSelf.cancelAssociatedTasksForReactor(at: index, with: .reactorTimedOut("\(reactor)"))
                                strongSelf.removeReactor(at: index)
                            }
                        }
                    }

                    maybeTimeoutWorkItem = timeoutWorkItem
                    strongSelf.interceptorQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem)
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
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        for handle in self.tasksToRequeue {
            if let data = self.data(for: handle) {
                log(from: self, "requeueing \(handle)", tags: TaskManager.kTkQTags)
                data.operation.markFinished()
                data.operation = TaskOperation(executor: data.operation.executor)
                data.operation.markReady()
                self.startTask(for: handle, with: data)
            }
        }
        self.tasksToRequeue = Set<OwnedTaskHandle>()
    }

    private func executeImmediateReactors(at indicies: [Int]) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.reactorQueue)
        }
        DispatchQueue.concurrentPerform(iterations: indicies.count) { index in
            let semaphore = DispatchSemaphore(value: 0)
            let reactor = self.reactors[index]
            log(from: self, "executing immediate reactor \(reactor.self)", tags: TaskManager.kReQTags)
            var maybeError: TaskError?
            reactor.execute { error in
                if let error = error {
                    maybeError = .reactorFailed(error)
                }
                semaphore.signal()
            }
            if let timeout = reactor.configuration.timeout, semaphore.wait(timeout: .now() + timeout) == .timedOut {
                maybeError = .reactorTimedOut("\(reactor)")
            } else {
                semaphore.wait()
            }
            guard let error = maybeError else {
                log(from: self, "executed immediate reactor \(reactor.self)", tags: TaskManager.kReQTags)
                return
            }
            log(from: self, "immediate reactor \(reactor.self) failed with: \(error)", tags: TaskManager.kReQTags)
            self.taskQueue.async { [weak self] in
                self?.cancelAssociatedTasksForReactor(at: index, with: .reactorFailed(error))
            }
        }
    }

    private func cancelAssociatedTasksForReactor(at index: Int, with error: TaskError) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        var allTheData: [TaskData] = []
        for handle in self.reactorAssoiciatedHandles[index] ?? Set<OwnedTaskHandle>() {
            if let data = self.data(for: handle, remove: true) {
                log(from: self, "removed handle \(handle) for reactor \(index)", tags: TaskManager.kTkQTags)
                data.operation.cancel()
                data.anyTask.didCancel(with: error)
                allTheData.append(data)
                if self.tasksToRequeue.remove(handle) != nil {
                    log(from: self, "removed \(handle) from requeue list", tags: TaskManager.kTkQTags)
                }
            }
        }
        self.reactorAssoiciatedHandles[index]?.removeAll()
        self.taskQueue.async {
            for data in allTheData {
                data.completionErrorCallback(error)
            }
        }
    }

    private func removeReactor(at index: Int) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        self.executingReactors.remove(index)
        if self.executingReactors.count == 0 {
            // Stop interceptor queue and ensure task queue is not suspended
            self.taskOperationQueue.isSuspended = false
            self.requeueTasks()
        }
    }

    private func removeAndCancel(handle: OwnedTaskHandle, with error: TaskError?) {
        if #available(iOS 10.0, *) {
            __dispatch_assert_queue(self.taskQueue)
        }
        guard let data = self.data(for: handle, remove: true) else {
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

    func start(handle: OwnedTaskHandle) {
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

    func taskState(for handle: OwnedTaskHandle) -> TaskState {
        let maybeOperation = self.taskQueue.sync { () -> TaskOperation? in
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
