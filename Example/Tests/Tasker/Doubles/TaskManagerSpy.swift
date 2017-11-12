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
import Quick
import Nimble
@testable import Swooft

class TaskManagerSpy {

    let taskManager: TaskManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }
    var completionCallData: [AnyResult] = []

    init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = []) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
    }

    @discardableResult
    func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        completion: (@escaping (T.TaskResult) -> Void) = { _ in }
    ) -> TaskHandle {
        return self.taskManager.add(task: task, startImmediately: startImmediately, after: interval) { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            defer {
                strongSelf.completionCallData.append(AnyResult(result))
            }
            completion(result)
        }
    }
}
