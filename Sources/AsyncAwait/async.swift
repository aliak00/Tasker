import Foundation

/**
 Calls an expression asynchronously and returns the result of the expressin in a the completion callback

 ```
 async(closingOver: loadVideoFile()) { result in
    switch result {
    case let .success(videoFil):
        break
    case let .failure(error):
        break
 }
 ```

 - parameter closure: the expression to call asynchronously
 - parameter completion: the callback with the result of the closure
 */
public func async<R>(closingOver closure: @escaping @autoclosure () -> R, completion: ((Result<R, Error>) -> Void)? = nil) {
    AnyTask<R> { callback in
        callback(.success(closure()))
    }.async { result in
        completion?(result)
    }
}

/**
 Calls a block of code asynchronously

 - parameter block: the block of code that should be called asynchronously
 */
public func async(executing block: @escaping () -> Void) {
    AnyTask { block() }.async { _ in }
}
