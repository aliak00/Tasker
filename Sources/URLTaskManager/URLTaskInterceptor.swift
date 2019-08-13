import Foundation

/**
 This protocol provides a means to intercept `URLTask`s.

 You only need to implement the specialized `intercept` function in this protocol.
 The protocol has default conformance to `TaskInterceptor`.
 */
public protocol URLTaskInterceptor : TaskInterceptor {
    func intercept(task: inout URLTask, currentBatchCount: Int) -> InterceptCommand
}

public extension URLTaskInterceptor {
    /**
     Default implementation of the `TaskInterceptor` protocol. If the tasks encountered are
     not `URLInterceptorTask` objects they are discarded
     */
    func intercept<T>(task: inout T, currentBatchCount: Int) -> InterceptCommand where T : Task {
        guard var task = task as? URLTask else {
            return .discard
        }
        return self.intercept(task: &task, currentBatchCount: currentBatchCount)
    }
}
