import Foundation

///
public typealias AnyResult = Result<Any>

public extension Result where T == Any {
    ///
    init<T>(_ result: Result<T>) {
        switch result {
        case let .success(value):
            self = .success(value)
        case let .failure(error):
            self = .failure(error)
        }
    }
}
