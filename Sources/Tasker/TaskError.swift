import Foundation

/**
 This enum represents the various errors that can occur during the execution of a task
*/
public enum TaskError: Error {
    /**
     A `TaskReactor`'s `execute` function failed.

     - parameter type: the `Type` of the `TaskReactor`
     - parameter error: The `Error` that the reactor failed with
     */
    case reactorFailed(type: TaskReactor.Type, error: Error)

    /**
     A `TaskReactor`'s `execute` function timed out.

     - parameter type: the `Type` of the `TaskReactor`
     */
    case reactorTimedOut(type: TaskReactor.Type)

    /// A task was cancelled
    case cancelled

    /// A task timed out
    case timedOut

    /// An unknown error occured
    case unknown
}
