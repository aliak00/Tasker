import Foundation

/**
 This protocol provides the means to react to a `URLTask` object.

 It also inherits from the `TaskReactor` protocol.
 */
public protocol URLTaskReactor : TaskReactor {
    func shouldExecute(after: URLTask.Result, from: URLTask, with: Handle) -> Bool
}

public extension URLTaskReactor {
    /**
     Default implementation of `TaskReactor.shouldExecute`. If the result type and task type are not
     the expected `URLTask` types then `shouldExecute` returns false.
     */
    func shouldExecute<T: Task>(after result: T.Result, from task: T, with handle: Handle) -> Bool {
        guard let task = task as? URLTask, let result = result as? URLTask.Result else {
            return false
        }
        return self.shouldExecute(after: result, from: task, with: handle)
    }

    func shouldExecute(after: URLTask.Result, from: URLTask, with: Handle) -> Bool {
        return false
    }
}
