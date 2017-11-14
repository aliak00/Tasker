//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

enum InterceptTaskResult {
    case ignore
    case execute([OwnedTaskHandle])
}

class TaskInterceptorManager {
    private let interceptorQueue = DispatchQueue(label: "Swooft.Tasker.TaskInterceptorManager.interceptors")
    private var batchedHandles: [Int: [Weak<OwnedTaskHandle>]] = [:]
    private let interceptors: [TaskInterceptor]

    init(_ interceptors: [TaskInterceptor]) {
        self.interceptors = interceptors
    }

    var count: Int {
        return self.interceptors.count
    }

    func intercept<T: Task>(
        task: inout T,
        for handle: OwnedTaskHandle,
        after interval: DispatchTimeInterval?,
        completion: @escaping (InterceptTaskResult) -> Void
    ) {
        if let interval = interval {
            self.interceptorQueue.asyncAfter(deadline: .now() + interval) { [task] in
                var task = task
                completion(self.intercept(task: &task, handle: handle))
            }
        } else {
            self.interceptorQueue.async { [task] in
                var task = task
                completion(self.intercept(task: &task, handle: handle))
            }
        }
    }

    private func intercept<T: Task>(task: inout T, handle: OwnedTaskHandle) -> InterceptTaskResult {
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
            log(from: self, "intercepting \(handle) with \(interceptor)")

            switch interceptor.intercept(task: &task, currentBatchCount: self.batchedHandles[index]?.count ?? 0) {
            case .forceExecute:
                shouldBeForceExecuted = true
                interceptorIndexHoldingTask = nil
                fallthrough
            case .execute:
                interceptorIndicesRequestingExecute.append(index)
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
            log(from: self, "discarding task for \(handle)")
            handle.discard()
            return .ignore
        }

        if let index = interceptorIndexHoldingTask, !shouldBeForceExecuted {
            log(from: self, "holding task for \(handle)")
            self.batchedHandles[index] = self.batchedHandles[index] ?? []
            self.batchedHandles[index]?.append(Weak(handle))
            return .ignore
        }

        var handlesToRelease: [OwnedTaskHandle] = []
        for index in interceptorIndicesRequestingExecute {
            for weakHandle in self.batchedHandles[index] ?? [] {
                if let handle = weakHandle.value {
                    handlesToRelease.append(handle)
                }
            }
            self.batchedHandles[index] = nil
        }

        log(from: self, "carrying on with task for \(handle)")

        if handlesToRelease.count > 0 {
            log(from: self, "\(handle) releasing batched handles \(handlesToRelease)")
        }

        let handles = handlesToRelease + [handle]
        return .execute(handles)
    }
}
