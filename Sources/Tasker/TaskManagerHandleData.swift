import Foundation

extension TaskManager.Handle {
    class Data {
        var operation: AsyncOperation
        let taskReference: AnyObject
        let completionErrorCallback: (TaskError) -> Void
        let taskDidCancelCallback: (TaskError) -> Void
        let intercept: (DispatchTimeInterval?, @escaping (TaskInterceptorManager.InterceptionResult) -> Void) -> Void
        let completionQueue: DispatchQueue?

        init(
            operation: AsyncOperation,
            taskReference: AnyObject,
            completionErrorCallback: @escaping (TaskError) -> Void,
            taskDidCancelCallback: @escaping (TaskError) -> Void,
            intercept: @escaping (DispatchTimeInterval?, @escaping (TaskInterceptorManager.InterceptionResult) -> Void) -> Void,
            completionQueue: DispatchQueue?
        ) {
            self.operation = operation
            self.taskReference = taskReference
            self.completionErrorCallback = completionErrorCallback
            self.taskDidCancelCallback = taskDidCancelCallback
            self.intercept = intercept
            self.completionQueue = completionQueue
        }
    }
}
