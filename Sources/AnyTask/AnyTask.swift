import Foundation

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
     be called with a `Task.CompletionCallback`

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    @discardableResult
    public init(timeout: DispatchTimeInterval? = nil, execute: @escaping (@escaping AnyTask.CompletionCallback) -> Void) {
        self.executeThunk = { completion in
            execute { result in
                completion(result)
            }
        }
        self.timeout = timeout
    }

    /**
     Initialize the AnyTask with an execution block that just returns a type T and may throw

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    @discardableResult
    public convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () throws -> T) {
        self.init(timeout: timeout) { completion in
            do {
                completion(.success(try execute()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /**
     Initialize the AnyTask with an execution block that must return a `Task.Result`

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    // TODO: Can this be made to work?
//    public convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> AnyTask.Result) {
//        self.init(timeout: timeout) { completion in
//            completion(execute())
//        }
//    }

    /**
     Initialize the AnyTask with an execution block that just returns a type T

     - parameter timeout: after how long the task timeout
     - parameter execute: the execution block.
     */
    @discardableResult
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
    @discardableResult
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
