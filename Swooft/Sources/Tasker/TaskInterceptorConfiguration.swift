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

// TODO:
enum InterceptorExecutionStyle {
    /// The interceptor is asynchronous, manager will fire it off and continue execution
    case asynchronous
    /// The interceptor is asynchronous, but the manager will wait till it's done callback is called before continuing
    case waitForCompletion
    /// The interceptor is immediate, the manager will assume it is done when it returns
    case immediate
}

public struct TaskInterceptorConfiguration {
    let isImmediate: Bool
    let timeout: DispatchTimeInterval?
    let requeuesTask: Bool
    let suspendsTaskQueue: Bool

    init(
        isImmediate: Bool = false,
        timeout: DispatchTimeInterval? = nil,
        requeuesTask: Bool = false,
        suspendsTaskQueue: Bool = false
    ) {
        self.isImmediate = isImmediate
        self.timeout = timeout
        self.requeuesTask = requeuesTask
        self.suspendsTaskQueue = suspendsTaskQueue
    }

    static let `default` = TaskInterceptorConfiguration()
}
