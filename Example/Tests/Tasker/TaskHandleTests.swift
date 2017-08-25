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

class TaskHandleTests: QuickSpec {
    override func spec() {

        describe("cancel") {

            it("should cancel a task") {
                let manager = TaskManagerSpy()
                let handle = manager.add(task: kDummyTask)
                handle.cancel()
                expect(handle.state) == TaskState.finished
                ensure(manager.completionHandlerCallCount).becomes(1)
                expect(manager.completionHandlerCallData[0]).to(failWith(TaskError.cancelled))
            }
        }

        describe("start") {

            it("should start a task") {
                let manager = TaskManagerSpy()
                let handle = manager.add(task: kDummyTask, startImmediately: false)
                ensure(handle.state).doesNotBecome(.finished)
                expect(handle.state) == TaskState.pending
                handle.start()
                expect(handle.state) == TaskState.executing
            }
        }
    }
}
