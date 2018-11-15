import Foundation

extension Task {
    @discardableResult
    public func async(
        with taskManager: TaskManager? = nil,
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: ResultCallback? = nil
    ) -> TaskHandle {
        return (taskManager ?? TaskManager.shared).add(
            task: self,
            after: interval,
            timeout: timeout,
            completeOn: queue,
            completion: completion
        )
    }
}

func async<R>(_ closure: @escaping @autoclosure () -> R, completion: ((Result<R>) -> Void)? = nil) {
    AnyTask<R> { callback in
        callback(.success(closure()))
    }.async { result in
        completion?(result)
    }
}
