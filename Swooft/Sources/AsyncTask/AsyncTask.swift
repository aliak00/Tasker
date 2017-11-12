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

//
// This is here because you cannot have stored static data in generic classes and it's convenient to be able
// to access the shared task manager for testing puposes.
//
struct AsyncTaskShared {
    static let taskManager = TaskManager()
}

private class _AsyncTask<T>: Task {

    typealias SuccessValue = T

    private let asyncTask: AsyncTask<T>
    private var queue: DispatchQueue?

    init(asyncTask: AsyncTask<T>, queue: DispatchQueue?, timeout: DispatchTimeInterval? = nil) {
        self.asyncTask = asyncTask
        self.queue = queue
        self.timeout = timeout
    }

    func execute(completion: @escaping ResultCallback) {
        let execute = {
            self.asyncTask.execute { result in
                completion(result)
            }
        }
        if let queue = self.queue {
            queue.async { execute() }
        } else {
            execute()
        }
    }

    var timeout: DispatchTimeInterval?
}

public class AsyncTask<T> {

    fileprivate let execute: (@escaping (Result<T>) -> Void) -> Void
    private var taskManager: TaskManager

    public init(taskManager: TaskManager? = nil, execute: @escaping (@escaping (Result<T>) -> Void) -> Void) {
        self.taskManager = taskManager ?? AsyncTaskShared.taskManager
        self.execute = execute
    }

    public convenience init(taskManager: TaskManager? = nil, execute: @escaping () -> Result<T>) {
        self.init(taskManager: taskManager) { callback in
            callback(execute())
        }
    }

    public convenience init(taskManager: TaskManager? = nil, execute: @escaping () -> T) {
        self.init(taskManager: taskManager) { callback in
            callback(.success(execute()))
        }
    }

    @discardableResult
    public func async(
        after interval: DispatchTimeInterval? = nil,
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: ((Result<T>) -> Void)? = nil
    ) -> TaskHandle {
        return self.taskManager.add(
            task: _AsyncTask<T>(asyncTask: self, queue: queue, timeout: timeout),
            after: interval,
            completion: completion
        )
    }

    public func await(
        queue: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        var maybeResult: _AsyncTask<T>.TaskResult?
        self.taskManager.add(
            task: _AsyncTask<T>(asyncTask: self, queue: queue, timeout: timeout),
            startImmediately: true
        ) { result in
            maybeResult = result
            semaphore.signal()
        }
        semaphore.wait()
        guard let result = maybeResult else {
            throw TaskError.unknown
        }
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}
