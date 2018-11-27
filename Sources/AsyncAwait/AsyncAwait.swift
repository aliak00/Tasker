import Foundation

///
public func async<R>(_ closure: @escaping @autoclosure () -> R, completion: ((Result<R>) -> Void)? = nil) {
    AnyTask<R> { callback in
        callback(.success(closure()))
    }.async { result in
        completion?(result)
    }
}

///
public func await<R>(_ closure: @escaping @autoclosure () -> R, timeout: DispatchTimeInterval? = nil) throws -> R {
    return try AnyTask<R> { callback in
        callback(.success(closure()))
    }.await(timeout: timeout)
}
