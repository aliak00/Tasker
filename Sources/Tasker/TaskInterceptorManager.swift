import Foundation

class TaskInterceptorManager {
    private static let kTags = [LogTags.onInterceptorQueue]

    enum InterceptionResult : Equatable {
        case ignore
        case execute([TaskManager.Handle])
    }

    private let queue = DispatchQueue(label: "Tasker.TaskInterceptorManager")
    private var batchedHandles: [Int: [Weak<TaskManager.Handle>]] = [:]

    let interceptors: [TaskInterceptor]

    init(_ interceptors: [TaskInterceptor]) {
        self.interceptors = interceptors
    }

    var count: Int {
        return self.queue.sync {
            self.interceptors.count
        }
    }

    func intercept<T: Task>(
        task: inout T,
        for handle: TaskManager.Handle,
        completion: @escaping (InterceptionResult) -> Void
    ) {
        self.queue.async { [task] in
            var task = task
            completion(self.intercept(task: &task, handle: handle))
        }
    }

    private func intercept<T: Task>(task: inout T, handle: TaskManager.Handle) -> InterceptionResult {
        // Calling an interceptor so we better be on the interceptor queue
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
                __dispatch_assert_queue(self.queue)
            #endif
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
        var shouldBeDiscarded = false
        var shouldBeForceExecuted = false
        var interceptorIndexHoldingTask: Int?
        var interceptorIndicesRequestingExecute: [Int] = []
        for (index, interceptor) in self.interceptors.enumerated() {
            log(from: self, "intercepting \(handle) with \(interceptor)", tags: TaskInterceptorManager.kTags)

            switch interceptor.intercept(task: &task, currentBatchCount: self.batchedHandles[index]?.count ?? 0) {
            case .forceExecute:
                shouldBeForceExecuted = true
                fallthrough
            case .execute:
                interceptorIndicesRequestingExecute.append(index)
            case .discard:
                shouldBeDiscarded = true
            case .hold:
                // First iterceptor to hold is the owner
                if interceptorIndexHoldingTask == nil {
                    interceptorIndexHoldingTask = index
                }
            }
        }

        // If we are discarding this and we did not encounter a force execute
        if shouldBeDiscarded, !shouldBeForceExecuted {
            log(from: self, "discarding task for \(handle)", tags: TaskInterceptorManager.kTags)
            handle.discard()
            return .ignore
        }

        // If we are holding this, and we did not encouter a force execute
        if let index = interceptorIndexHoldingTask, !shouldBeForceExecuted {
            log(from: self, "holding task for \(handle)", tags: TaskInterceptorManager.kTags)
            self.batchedHandles[index] = self.batchedHandles[index] ?? []
            self.batchedHandles[index]?.append(Weak(handle))
            return .ignore
        }

        // We are not discarding and we are not holding, so lets execute everything we can

        var handlesToRelease: [TaskManager.Handle] = []
        for index in interceptorIndicesRequestingExecute {
            // Some interceptor asked for execution, so let's get all the batched
            // handles for this interceptor
            for weakHandle in self.batchedHandles[index] ?? [] {
                if let handle = weakHandle.value {
                    handlesToRelease.append(handle)
                }
            }
            self.batchedHandles[index] = nil
        }

        log(from: self, "carrying on with task for \(handle)", tags: TaskInterceptorManager.kTags)

        if handlesToRelease.count > 0 {
            log(from: self, "\(handle) releasing batched handles \(handlesToRelease)", tags: TaskInterceptorManager.kTags)
        }

        let handles = handlesToRelease + [handle]
        return .execute(handles)
    }
}
