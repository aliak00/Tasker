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

public class AnyTask: Task {

    public typealias SuccessValue = Any

    var executeThunk: (@escaping ResultCallback) -> Void
    var internalTask: AnyObject?

    public init<T>(timeout: DispatchTimeInterval? = nil, execute: (@escaping (@escaping (Result<T>) -> Void) -> Void)) {
        self.executeThunk = { callback in
            execute { result in
                callback(AnyResult(result))
            }
        }
        self.timeout = timeout
    }

    public convenience init<T>(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> Result<T>) {
        self.init(timeout: timeout) { callback in
            callback(execute())
        }
    }

    public convenience init<T>(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> T) {
        self.init(timeout: timeout) { callback in
            callback(.success(execute()))
        }
    }

    public init<U: Task>(_ task: U) {
        self.executeThunk = { cb in
            task.execute { result in
                cb(AnyResult(result))
            }
        }
        self.timeout = task.timeout
        self.internalTask = task
    }

    public var timeout: DispatchTimeInterval?

    public func execute(completion: @escaping ResultCallback) {
        self.executeThunk(completion)
    }
}

