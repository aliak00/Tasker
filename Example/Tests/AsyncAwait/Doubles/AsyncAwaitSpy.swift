//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation
import Swooft

class AsyncAwaitSpy<T>: TaskSpy<T> {

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: [Result<T>] = []

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> Result<T>) {
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
        completion: ((Result<T>) -> Void)? = nil
    ) -> TaskHandle {
        return super.async(with: nil, after: interval, queue: queue, timeout: timeout) { result in
            defer {
                self.completionCallData.append(result)
            }
            completion?(result)
        }
    }

    @discardableResult
    func await(queue: DispatchQueue? = nil, timeout: DispatchTimeInterval? = nil) throws -> T {
        do {
            let value = try super.await(queue: queue, timeout: timeout)
            self.completionCallData.append(.success(value))
            return value
        } catch {
            self.completionCallData.append(.failure(error))
            throw error
        }
    }
}
