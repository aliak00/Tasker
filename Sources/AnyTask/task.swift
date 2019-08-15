import Foundation

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

 - parameter closingOver: the expression to create a task out of
 */
public func task<R>(closingOver closure: @escaping @autoclosure () -> R) -> AnyTask<R> {
    return AnyTask<R> { callback in
        callback(.success(closure()))
    }
}

/**
 Creates a task out of a function that has a `done` callback. I.e.

 ```
 let f = { (done: @escaping () -> Void) -> Void in
    DispatchQueue.global(qos: .unspecified).async {
        // Do some long running calculation
        done()
    }
 }
 let t = task(executing: f)
 ```

 - parameter executing: an asynchronous function that has a `done` callback as it's only parameter. The `done` callback
 must be called when the asynchronous operation completes.
 */
public func task(executing block: @escaping (@escaping () -> Void) -> Void) -> AnyTask<Void> {
    return AnyTask<Void> { callback in
        block {
            callback(.success(()))
        }
    }
}

/**
 Creates a task out of a function that has a `done` callback with a specific signature

 - parameter executing: an asynchronous function that has a `done` callback as it's only parameter. The done callback
 must take the expected value of the asynchronous operation as its only parameter
 */
public func task<T>(executing block: @escaping (@escaping (T) -> Void) -> Void) -> AnyTask<T> {
    return AnyTask<T> { callback in
        block { result in
            callback(.success(result))
        }
    }
}

/**
 Creates a task out of a function that has a `done` callback with a specific signature

 - parameter executing: an asynchronous function that has a `done` callback as it's only parameter. The done callback
 must take the expected `Result<T, Error>` of the asynchronous operation as its only parameter
 */
public func task<T>(executing block: @escaping (@escaping (Result<T, Error>) -> Void) -> Void) -> AnyTask<T> {
    return AnyTask<T> { callback in
        block { result in
            do {
                let value = try result.get()
                callback(.success(value))
            } catch {
                callback(.failure(error))
            }
        }
    }
}
