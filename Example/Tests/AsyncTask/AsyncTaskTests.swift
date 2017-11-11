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

class AsyncTaskTests: QuickSpec {

    override func spec() {

        afterEach {
            AsyncTaskShared.taskManager.waitTillAllTasksFinished()
        }

        describe("async") {

            it("should call execute") {
                let task = AsyncTaskSpy {}
                task.async()
                ensure(task.completionHandlerCallCount).becomes(1)
            }

            it("should get cancelled error") {
                let task = AsyncTaskSpy { sleep(for: .milliseconds(5)) }
                let handle = task.async()
                handle.cancel()
                ensure(task.completionHandlerCallCount).becomes(1)
                expect(task.completionHandlerCallData[0]).to(failWith(TaskError.cancelled))
            }

            it("should timeout after deadline reached") {
                let task = AsyncTaskSpy { sleep(for: .milliseconds(5)) }
                let handle = task.async(timeout: .milliseconds(1))
                ensure(task.completionHandlerCallCount).becomes(1)
                expect(task.completionHandlerCallData[0]).to(failWith(TaskError.timedOut))
                ensure(handle.state).becomes(.finished)
            }
        }

        describe("await") {

            it("should return value") {
                let task = AsyncTaskSpy { true }
                let value = try! task.await()
                expect(value).to(beTrue())
                ensure(task.completionHandlerCallCount).stays(1)
            }

            it("should turn async in to sync") {
                let task = AsyncTaskSpy { () -> Int in
                    sleep(for: .milliseconds(1))
                    return 3
                }
                let value = try! task.await()
                expect(value).to(equal(3))
                ensure(task.completionHandlerCallCount).stays(1)
            }

            it("should timeout after deadline reached") {
                let task = AsyncTaskSpy { sleep(for: .milliseconds(5)) }
                var maybeError: Error?
                do {
                    try task.await(timeout: .milliseconds(1))
                } catch {
                    maybeError = error
                }
                expect(maybeError).to(matchError(TaskError.timedOut))
                ensure(task.completionHandlerCallCount).stays(1)
            }
        }
    }
}
