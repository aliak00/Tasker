import Foundation

/**
 A task is any unit of work that is to be carried out. It is protocol based and has a main function called `execute`
 that is called when the task is supposed to be executed. When a task is completed, a completion callback is called
 and passed the result of the task, which is a `Result<SuccessValue, Error>`.

 ## Timeouts

 Tasks can implement a timeout that will determine when the `TaskManager` is to give up on the task.

 ## Cancellation

 And finally, every task has a `Task.didCancel(with:)` that is passed a `TaskError` that tells the `Task` object
 why the task was cancelled. The `didCancel` will only be called after the task has been removed from the
 `TaskManager`.

 ## Notes

 Tasks are reference types because the task manager has to keep track of all the tasks that are floating around.

 */
public protocol Task: AnyObject {
    /// The type of a successful execution of a task
    associatedtype SuccessValue

    /// Covenience typealias for the result of `execute`
    typealias Result = Swift.Result<SuccessValue, Error>

    /// Conveneience typealias for the completion callback of `execute`
    typealias CompletionCallback = (Result) -> Void

    /**
     The function that executes the task

     - parameter completion: the completion callback that the implementaiton must call when it is done with its work
     */
    func execute(completion: @escaping CompletionCallback)

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
        nil
    }

    func didCancel(with _: TaskError) {}
}
