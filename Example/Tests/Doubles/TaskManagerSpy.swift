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

private class TaskManagerSpyConfiguration: QuickConfiguration {
    override class func configure(_ configuration: Configuration) {
        configuration.afterEach {
            TaskManagerSpy.shared.reset()
        }
    }
}

class TaskManagerSpy {

    static let shared = TaskManagerSpy()

    let taskManager: TaskManager

    var completionHandlerCallCount: Int = 0
    var completionHandlerCallData: [AnyResult] = []

    func reset() {
        self.completionHandlerCallCount = 0
        self.completionHandlerCallData.removeAll()
    }

    init(interceptors: [TaskInterceptor] = []) {
        self.taskManager = TaskManager(interceptors: interceptors)
    }

    @discardableResult
    func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        completionHandler: (@escaping (T.TaskResult) -> Void) = { _ in }
    ) -> TaskHandle {
        return self.taskManager.add(task: task, startImmediately: startImmediately, after: interval) { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            strongSelf.completionHandlerCallData.append(AnyResult(result))
            completionHandler(result)
            strongSelf.completionHandlerCallCount += 1
        }
    }
}
