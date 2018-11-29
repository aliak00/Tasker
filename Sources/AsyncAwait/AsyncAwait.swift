import Foundation

/**
 Calls an expression asynchronously and returns the result of the expressin in a the completion callback

 ```
 async(loadVideoFile()) { result in
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
public func async<R>(_ closure: @escaping @autoclosure () -> R, completion: ((Result<R>) -> Void)? = nil) {
    AnyTask<R> { callback in
        callback(.success(closure()))
    }.async { result in
        completion?(result)
    }
}

/**
 Creates a task out of an expression and returns it as an `AnyTask`

 ```
 let x = task(someLongOperation())

 x.async { result in
    // stuff
 }

 // or

 let result = x.await()
 ```

 - parameter closure: the expression to create a task out of
 */
public func task<R>(_ closure: @escaping @autoclosure () -> R) -> AnyTask<R> {
    return AnyTask<R> { callback in
        callback(.success(closure()))
    }
}

/**
 Calls an asynchronous function and waits for the result. The function that is passed in must have a completion
 callback, and this is assumed to be the callback that is called when the asynchronous function is done
 computing the result, e.g.:

 ```
 let f = { (done: @escaping (Int) -> Void) -> Void in
     DispatchQueue.global(qos: .unspecified).async {
         // Do some long running calculation
         done(5)
     }
 }

 XCTAssertEqual(try await(f), 5)
 ```

 - parameter closure: the expression to call asynchronously
 - parameter completion: the callback with the result of the closure
 */
public func await<T>(_ function: @escaping (@escaping (T) -> Void) -> Void, timeout: DispatchTimeInterval? = nil) throws -> T {
    return try AnyTask<T> { callback in
        function { result in
            callback(.success(result))
        }
    }.await(timeout: timeout)
}