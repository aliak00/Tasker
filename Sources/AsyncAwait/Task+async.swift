import Foundation

extension Task {
    /**
     Will execute the task asynchronously

     - parameter taskManager: which instance of `TaskManager` you want to use. Defaults to `TaskManager.shared`
     - parameter after: after how long you want the task to start being executed
     - parameter startImmediately: set this to false if you want to explicity call start on the `Handle` that's returned
     - parameter queue: on which DispatchQueue you want the completion callback to be called
     - parameter timeout: after how long should the task timeout. This overwrites `Task.timeout` if there is one
     - parameter completion: the reuslt of the operation will be passed here
     */
    @discardableResult
    public func async(
        using taskManager: TaskManager? = nil,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: CompletionCallback? = nil
    ) -> Handle {
        (taskManager ?? TaskManager.shared).add(
            task: self,
            startImmediately: startImmediately,
            after: interval,
            timeout: timeout,
            completeOn: queue,
            completion: completion
        )
    }
}
