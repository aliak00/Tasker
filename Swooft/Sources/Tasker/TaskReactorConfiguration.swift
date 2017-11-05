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

public struct TaskReactorConfiguration {
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

    static let `default` = TaskReactorConfiguration()
}
