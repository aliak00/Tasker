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

class TaskInterceptorTests: QuickSpec {
    override func spec() {

        describe("intercept") {

            it("should be called with task") {
                let interceptor = InterceptorSpy()
                let manager = TaskManagerSpy(interceptors: [interceptor])
                let task = SuccessTaskSpy()
                manager.add(task: task)
                ensure(interceptor.interceptCallCount).becomes(1)
                expect(interceptor.interceptCallData[0].weakAnyTask.anyTask) === task
            }

            it("should modify original task") {
                let interceptor = InterceptorSpy()
                interceptor.interceptBlock = { anyTask, _ in
                    let task = anyTask.internalTask as! SuccessTaskSpy
                    task.executeCallCount = 100
                    return .execute
                }
                let manager = TaskManagerSpy(interceptors: [interceptor])
                let task = SuccessTaskSpy()
                manager.add(task: task)
                ensure(interceptor.interceptCallCount).becomes(1)
                ensure(task.executeCallCount).becomes(101)
            }
        }
    }
}
