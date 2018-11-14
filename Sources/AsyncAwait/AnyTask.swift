import Foundation

///
public class AnyTask<T>: Task {
    public typealias SuccessValue = T

    var executeThunk: (@escaping ResultCallback) -> Void

    public init(timeout: DispatchTimeInterval? = nil, execute: (@escaping (@escaping ResultCallback) -> Void)) {
        self.executeThunk = { completion in
            execute { result in
                completion(result)
            }
        }
        self.timeout = timeout
    }

    public convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> Result<T>) {
        self.init(timeout: timeout) { completion in
            completion(execute())
        }
    }

    public convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> T) {
        self.init(timeout: timeout) { completion in
            completion(.success(execute()))
        }
    }

    public init<U: Task>(_ task: U) where U.SuccessValue == SuccessValue {
        self.executeThunk = { completion in
            task.execute { result in
                completion(result)
            }
        }
        self.timeout = task.timeout
    }

    public var timeout: DispatchTimeInterval?

    public func execute(completion: @escaping ResultCallback) {
        self.executeThunk(completion)
    }
}

extension AnyTask where T == Any {
    public convenience init<U: Task>(_ task: U) {
        self.init(timeout: task.timeout) { completion in
            task.execute { result in
                completion(AnyResult(result))
            }
        }
    }
}
