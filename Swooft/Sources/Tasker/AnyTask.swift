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

public class AnyTask<T>: Task {

    public typealias SuccessValue = T

    var executeBlock: (@escaping ResultCallback) -> Void

    var internalTask: Any?

    init(timeout: DispatchTimeInterval? = nil, executeBlock: (@escaping (@escaping ResultCallback) -> Void)) {
        self.executeBlock = executeBlock
        self.timeout = timeout
    }

    init<U: Task>(task: U) where U.SuccessValue == SuccessValue {
        self.executeBlock = { cb in
            task.execute(completionHandler: cb)
        }
        self.timeout = task.timeout
        self.internalTask = task
    }

    public var timeout: DispatchTimeInterval?

    public func execute(completionHandler: @escaping ResultCallback) {
        self.executeBlock(completionHandler)
    }
}

extension AnyTask where T == Any {
    convenience init<U: Task>(task: U) {
        self.init(timeout: task.timeout) { cb in
            task.execute { result in
                cb(AnyResult(result))
            }
        }
        self.internalTask = task
    }
}


