import Foundation

private class ArrayOfTasks<T: AnyTaskConvertible>: Task {
    typealias SuccessValue = [Result<T.SuccessValue, Error>]
    let array: [T]
    init(_ array: [T]) {
        self.array = array
    }

    func execute(completion: @escaping (Result<[Result<T.SuccessValue, Error>], Error>) -> Void) {
        let results = SynchronizedArray<Result<T.SuccessValue, Error>>()
        for task in self.array {
            task.anyTask.async {
                results.append($0)
                if results.count == self.array.count {
                    completion(.success(results.data))
                }
            }
        }
    }
}

extension Array where Element: AnyTaskConvertible {
    /**
     Executes each task in this array and returns an array of `Result`s in the completion block

     The results are not in the same order as the array of tasks.

     SeeAlso: `Task.async(...)`
     */
    @discardableResult
    public func async(
        with taskManager: TaskManager? = nil,
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: ((Result<[Result<Element.SuccessValue, Error>], Error>) -> Void)? = nil
    ) -> Handle {
        return ArrayOfTasks(self)
            .async(
                with: taskManager,
                after: interval,
                queue: queue,
                timeout: timeout,
                completion: completion
            )
    }

    /**
     Executes each task in line and awaits an array of each tasks' result

     The results are not in the same order as the array of tasks.

     SeeAlso: `Task.await(...)`
     */
    public func await(
        with taskManager: TaskManager? = nil,
        timeout: DispatchTimeInterval? = nil
    ) throws -> [Result<Element.SuccessValue, Error>] {
        return try ArrayOfTasks(self).await(with: taskManager, timeout: timeout)
    }
}
