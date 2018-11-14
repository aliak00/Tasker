import Foundation

public enum Result<T> {
    case success(T)
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
