import Foundation

public protocol Task: class {
    associatedtype SuccessValue
    typealias Result = Tasker.Result<SuccessValue>
    typealias ResultCallback = (Result) -> Void
    func execute(completion: @escaping ResultCallback)
    var timeout: DispatchTimeInterval? { get }
    func didCancel(with _: TaskError)
}

public extension Task {
    var timeout: DispatchTimeInterval? {
        return nil
    }

    func didCancel(with _: TaskError) {}
}
