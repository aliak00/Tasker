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

public func task(executing block: @escaping (@escaping () -> Void) -> Void) -> AnyTask<Void> {
    return AnyTask<Void> { callback in
        block {
            callback(.success(()))
        }
    }
}

public func task<T>(executing block: @escaping (@escaping (T) -> Void) -> Void) -> AnyTask<T> {
    return AnyTask<T> { callback in
        block { result in
            callback(.success(result))
        }
    }
}

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
