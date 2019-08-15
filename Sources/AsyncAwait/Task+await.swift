import Foundation

extension Task {
    /**
     Will execute the task synchronously and await the result. Throws an error on failure.

     - parameter taskManager: which instance of `TaskManager` you want to use. Defaults to `TaskManager.shared`
     - parameter timeout: after how long should the task timeout. This overwrites `Task.timeout` if there is one
     */
    public func await(
        using taskManager: TaskManager? = nil,
        timeout: DispatchTimeInterval? = nil
    ) throws -> SuccessValue {
        let semaphore = DispatchSemaphore(value: 0)
        var maybeResult: Self.Result?
        let handle = (taskManager ?? TaskManager.shared).add(
            task: self,
            startImmediately: true
        ) { result in
            maybeResult = result
            semaphore.signal()
        }
        if let timeout = timeout, semaphore.wait(timeout: .now() + timeout) == .timedOut {
            handle.cancel()
            throw TaskError.timedOut
        } else {
            semaphore.wait()
        }
        guard let result = maybeResult else {
            throw TaskError.unknown
        }
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}
