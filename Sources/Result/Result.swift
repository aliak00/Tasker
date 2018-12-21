import Foundation

/**
 This associated enum encapsulates either a success value of an error. This is used by most of the
 functions that work with a completion callback
 */
public enum Result<T> {

    /// Represents a successful result
    case success(T)

    /// Represents a failure result
    case failure(Error)

    var successValue: T? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var failureValue: Error? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }

    func materialize() throws -> T {
        switch self {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}
