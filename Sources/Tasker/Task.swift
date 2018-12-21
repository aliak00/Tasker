import Foundation

/**
 A task is any unit of work that is to be carried out. It is protocol based and has a main function called `execute`
 that is called when the task is supposed to be executed. When a task is completed, a callback with a `Result<T>`
 is called by the implementaiton of the `Task`.
 */
public protocol Task: class {

    /// The type of a successful execution of a task
    associatedtype SuccessValue

    /// Covenience typealias for the result of `execute`
    typealias Result = Tasker.Result<SuccessValue>

    /// Conveneience typealias for the completion callback of `execute`
    typealias ResultCallback = (Result) -> Void

    /**
     The function that executes the task

     - parameter completion: the completion callback that the implementaiton must call when it is done with its work
     */
    func execute(completion: @escaping ResultCallback)

    /// How long does is the `execute` function allowed to take
    var timeout: DispatchTimeInterval? { get }

    /**
     This is called if for any reason this task was cancelled.

     - parameter with: the `TaskError` that caused the cancellation
     */
    func didCancel(with _: TaskError)
}

public extension Task {
    var timeout: DispatchTimeInterval? {
        return nil
    }

    func didCancel(with _: TaskError) {}
}
