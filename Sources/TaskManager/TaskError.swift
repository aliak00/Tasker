import Foundation

/**
 This enum represents the various errors that can occur during the execution of a task
 */
public enum TaskError: Error {
    /**
     A `Reactor`'s `execute` function failed.

     - parameter type: the `Type` of the `Reactor`
     - parameter error: The `Error` that the reactor failed with
     */
    case reactorFailed(type: Reactor.Type, error: Error)

    /**
     A `Reactor`'s `execute` function timed out.

     - parameter type: the `Type` of the `Reactor`
     */
    case reactorTimedOut(type: Reactor.Type)

    /// A task was cancelled
    case cancelled

    /// A task timed out
    case timedOut

    /// An unknown error occured
    case unknown
}
