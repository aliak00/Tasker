import Foundation
@testable import Tasker

class AsyncAwaitSpy<T>: TaskSpy<T> {
    var completionCallCount: Int {
        self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<AsyncAwaitSpy.Result> = []

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> AsyncAwaitSpy.Result) {
        self.init(timeout: timeout) { completion in
            completion(execute())
        }
    }

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> T) {
        self.init(timeout: timeout) { completion in
            completion(.success(execute()))
        }
    }

    @discardableResult
    func async(
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: CompletionCallback? = nil
    ) -> Handle {
        super.async(using: nil, after: interval, queue: queue, timeout: timeout) { [weak self] result in
            defer {
                self?.completionCallData.append(result)
            }
            completion?(result)
        }
    }

    @discardableResult
    func await(timeout: DispatchTimeInterval? = nil) throws -> T {
        do {
            let value = try super.await(timeout: timeout)
            self.completionCallData.append(.success(value))
            return value
        } catch {
            self.completionCallData.append(.failure(error))
            throw error
        }
    }
}
