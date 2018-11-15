import Foundation

extension Task {
    public func await(
        with taskManager: TaskManager? = nil,
        queue _: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil
    ) throws -> SuccessValue {
        let semaphore = DispatchSemaphore(value: 0)
        var maybeResult: Result?
        (taskManager ?? TaskManager.shared).add(
            task: self,
            startImmediately: true
        ) { result in
            maybeResult = result
            semaphore.signal()
        }
        if let timeout = timeout, semaphore.wait(timeout: .now() + timeout) == .timedOut {
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

func await<R>(_ closure: @escaping @autoclosure () -> R, timeout: DispatchTimeInterval? = nil) throws -> R {
    return try AnyTask<R> { callback in
        callback(.success(closure()))
    }.await(timeout: timeout)
}
