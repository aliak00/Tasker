import Foundation

///
public enum TaskError: Error {
    ///
    case reactorFailed(type: TaskReactor.Type, error: Error)
    ///
    case reactorTimedOut(type: TaskReactor.Type)
    ///
    case cancelled
    ///
    case timedOut
    ///
    case unknown
}
