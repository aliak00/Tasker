import Foundation

private class ArrayOfTasks<T: Task>: Task {

    let array: [T]
    let inOrder: Bool

    init(_ array: [T], inOrder: Bool) {
        self.array = array
        self.inOrder = inOrder
    }

    typealias SuccessValue = [Result<T.SuccessValue, Error>]

    func execute(completion: @escaping (Result<[Result<T.SuccessValue, Error>], Error>) -> Void) {
        if self.inOrder {
            var results: [Result<T.SuccessValue, Error>] = []
            for task in self.array {
                do {
                    let result = try task.await()
                    results.append(.success(result))
                } catch {
                    results.append(.failure(error))
                }
            }
            completion(.success(results))
        } else {
            if self.array.count == 0 {
                completion(.success([]))
            }
            let results = SynchronizedArray<Result<T.SuccessValue, Error>>()
            for task in self.array {
                task.async {
                    results.append($0)
                    if results.count == self.array.count {
                        completion(.success(results.data))
                    }
                }
            }
        }
    }
}

extension Array where Element: Task {
    /**
     Executes each task in this array and returns an array of `Result`s in the completion block

     - parameter inOrder: true if you want the tasks executed strictly one after the other

     SeeAlso: `Task.async(...)` for the rest of the parameters
     */
    @discardableResult
    public func async(
        using taskManager: TaskManager? = nil,
        inOrder: Bool = false,
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: ((Result<[Result<Element.SuccessValue, Error>], Error>) -> Void)? = nil
    ) -> Handle {
        ArrayOfTasks(self, inOrder: inOrder)
            .async(
                using: taskManager,
                after: interval,
                queue: queue,
                timeout: timeout,
                completion: completion
            )
    }

    /**
     Executes each task in line and awaits an array of each tasks' result

     - parameter inOrder: true if you want the tasks executed strictly one after the other

     SeeAlso: `Task.await(...)` for the rest of the parameters
     */
    public func await(
        using taskManager: TaskManager? = nil,
        inOrder: Bool = false,
        timeout: DispatchTimeInterval? = nil
    ) throws -> [Result<Element.SuccessValue, Error>] {
        try ArrayOfTasks(self, inOrder: inOrder)
            .await(using: taskManager, timeout: timeout)
    }
}
