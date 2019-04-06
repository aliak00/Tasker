import Foundation

///
public typealias AnyResult = Result<Any, Error>

public extension Result where Success == Any, Failure == Error {
    ///
    init<T, E: Error>(_ result: Result<T, E>) {
        switch result {
        case let .success(value):
            self = .success(value)
        case let .failure(error):
            self = .failure(error)
        }
    }
}
