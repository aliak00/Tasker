/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import Swooft

class AsyncTaskSpy<T> {
    var asyncTask: AsyncTask<T>

    var completionCallCount: Int {
        return self.completionCallData.count
    }
    var completionCallData: [Result<T>] = []

    public init(execute: @escaping (@escaping (Result<T>) -> Void) -> Void) {
        self.asyncTask = AsyncTask(execute: execute)
    }

    public init(execute: @escaping () -> Result<T>) {
        self.asyncTask = AsyncTask(execute: execute)
    }

    public init(execute: @escaping () -> T) {
        self.asyncTask = AsyncTask(execute: execute)
    }

    @discardableResult
    public func async(
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: ((Result<T>) -> Void)? = nil
    ) -> TaskHandle {
        return self.asyncTask.async(after: interval, queue: queue, timeout: timeout) { result in
            defer {
                self.completionCallData.append(result)
            }
            completion?(result)
        }
    }

    @discardableResult
    public func await(queue: DispatchQueue? = nil, timeout: DispatchTimeInterval? = nil) throws -> T {
        do {
            let value = try self.asyncTask.await(queue: queue, timeout: timeout)
            self.completionCallData.append(.success(value))
            return value
        } catch {
            self.completionCallData.append(.failure(error))
            throw error
        }
    }
}