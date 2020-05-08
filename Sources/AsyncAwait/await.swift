import Foundation

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

 - parameter timeout: how long to wait or this function to finish
 - parameter block: an asynchronous function that has a `done` callback as it's only parameter. The done callback
    must take the expected value of the asynchronous operation as its only parameter
 */
public func await<T>(timeout: DispatchTimeInterval? = nil, block: @escaping (@escaping (T) -> Void) -> Void) throws -> T {
    try task(executing: block).await(timeout: timeout)
}

/**
 Calls an asynchronous function and waits for completion. The function that is passed in must have a completion
 callback, and this is assumed to be the callback that is called when the asynchronous function is done.

 - parameter block: an asynchronous function that has a `done` callback as it's only parameter. The `done` callback
    must be called when the asynchronous operation completes.
 - parameter timeout: how long to wait or this function to finish
 */
public func await(timeout: DispatchTimeInterval? = nil, block: @escaping (() -> Void) -> Void) throws {
    try task(executing: block).await(timeout: timeout)
}

/**
 Calls an asynchronous function and waits for the result. The function that is passed in must have a completion
 callback, and this is assumed to be the callback that is called when the asynchronous function is done
 computing the result

 - parameter block: an asynchronous function that has a `done` callback as it's only parameter. The done callback
    must take the expected `Result<T, Error>` of the asynchronous operation as its only parameter
 - parameter timeout: how long to wait or this function to finish
 */
public func await<T>(timeout: DispatchTimeInterval? = nil, block: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) throws -> T {
    try task(executing: block).await(timeout: timeout)
}
