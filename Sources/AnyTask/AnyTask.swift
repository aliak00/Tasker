import Foundation

/**
 This protocol is used to be able to provide extensions on types that have generic parameters.

 Since you cannot do

 ```
 extension Array where Element == AnyTask<T>
 ```

 The workaround is to declare a protocol and have AnyTask conform to that protocol, then you can:

 ```
 extension Array where Element == AnyTaskConvertible
 ```

 SeeAlso:
 - `Array.async(...)`
 - `Array.await(...)`
 */
public protocol AnyTaskConvertible {
    associatedtype SuccessValue: Any
    var anyTask: AnyTask<SuccessValue> { get }
}

extension AnyTask: AnyTaskConvertible {
    public var anyTask: AnyTask<SuccessValue> { return self }
}

/**
 An AnyTask can be used as a generic `Task` object. You have to pass it a execute block when it's initialized
 and that will be called when it's time to execute the task.

 `AnyTask`s schedules execution blocks on `TaskManager.shared`.
 */
public class AnyTask<T>: Task {
    /**
     Alias of the "successful" return value of your execution block
     */
    public typealias SuccessValue = T

    var executeThunk: (@escaping CompletionCallback) -> Void

    /**
     Initialize the AnyTask with an execution block that is given a "done" callback that must
     be called with a `Task.ResultCallback`

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    public init(timeout: DispatchTimeInterval? = nil, execute: @escaping (@escaping AnyTask.CompletionCallback) -> Void) {
        self.executeThunk = { completion in
            execute { result in
                completion(result)
            }
        }
        self.timeout = timeout
    }

    /**
     Initialize the AnyTask with an execution block that must return a `Task.Result`

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    public convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> AnyTask.Result) {
        self.init(timeout: timeout) { completion in
            completion(execute())
        }
    }

    /**
     Initialize the AnyTask with an execution block that just returns a type T

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    public convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> T) {
        self.init(timeout: timeout) { completion in
            completion(.success(execute()))
        }
    }

    /**
     Initialize the AnyTask with another `Task` object. The `Task.SuccessValue` must match the
     type T of this AnyTask

     - parameter task: The `Task` object that this will wrap
     - parameter timeout: Specify if you wan to overwrites `Task.timeout`.
     */
    public convenience init<U: Task>(fromTask task: U, timeout: DispatchTimeInterval? = nil) where U.SuccessValue == SuccessValue {
        self.init(timeout: timeout ?? task.timeout) { completion in
            task.execute(completion: completion)
        }
    }

    /**
     The timeout passed in the initializer
     */
    public let timeout: DispatchTimeInterval?

    /**
     The `Task.execute` function calls the execution block was given to an initilzer
     */
    public func execute(completion: @escaping CompletionCallback) {
        self.executeThunk(completion)
    }
}

extension AnyTask where T == Any {
    ///
    public convenience init<U: Task>(_ task: U) {
        self.init(timeout: task.timeout) { completion in
            task.execute { result in
                completion(AnyResult(result))
            }
        }
    }
}
