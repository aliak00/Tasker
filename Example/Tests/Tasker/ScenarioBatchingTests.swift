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

import Quick
import Nimble
@testable import Swooft

// This interceptor will take any task that is retriable, and re-execute it
class BatchingInterceptor: TaskInterceptor {
    func intercept<T: Task>(task _: inout T, currentBatchCount: Int) -> InterceptCommand {
        return currentBatchCount < 9 ? .hold : .execute
    }
}

class ScenarioBatchingTests: QuickSpec {

    override func spec() {

        it("should all work") {
            let manager = TaskManagerSpy(interceptors: [BatchingInterceptor()])
            for i in 0..<9 {
                manager.add(task: TaskSpy { $0(.success(i)) })
            }
            ensure(manager.completionCallCount).stays(0)
            manager.add(task: TaskSpy { $0(.success(())) })
            ensure(manager.completionCallCount).becomes(10)
        }
    }
}
