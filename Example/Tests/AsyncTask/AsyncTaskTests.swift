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

        it("should work") {
            let task = AsyncTaskSpy { () -> Int in
                let one = try! TaskSpy<Int> { callback in
                    sleep(for: .milliseconds(1))
                    callback(.success(1))
                }.await()
                let two = try! TaskSpy<Int> { callback in
                    sleep(for: .milliseconds(1))
                    callback(.success(2))
                }.await()
                return one + two
            }
            task.async()
            ensure(task.completionCallCount).becomes(1)
            ensure(task.completionCallData[0].successValue).becomes(3)
        }

        describe("async") {

            it("should call execute") {
                let task = AsyncTaskSpy {}
                task.async()
                ensure(task.completionCallCount).becomes(1)
            }

            it("should get cancelled error") {
                let task = AsyncTaskSpy { sleep(for: .milliseconds(5)) }
                let handle = task.async()
                handle.cancel()
                ensure(task.completionCallCount).becomes(1)
                expect(task.completionCallData[0]).to(failWith(TaskError.cancelled))
            }

            it("should timeout after deadline reached") {
                let task = AsyncTaskSpy { sleep(for: .milliseconds(5)) }
                let handle = task.async(timeout: .milliseconds(1))
                ensure(task.completionCallCount).becomes(1)
                expect(task.completionCallData[0]).to(failWith(TaskError.timedOut))
                ensure(handle.state).becomes(.finished)
            }

//            it("should call completion on specified queue") {
//                let queue = DispatchQueue(label: "Swooft.Tests.AsyncTask")
//                let key = DispatchSpecificKey<Void>()
//                queue.setSpecific(key: key, value: ())
//                let task = AsyncTaskSpy {
//                    expect(DispatchQueue.getSpecific(key: key)).toNot(beNil())
//                }
//                task.async(queue: queue)
//                ensure(task.completionCallCount).becomes(1)
//            }
        }

        describe("await") {

            it("should return value") {
                let task = AsyncTaskSpy { true }
                let value = try! task.await()
                expect(value).to(beTrue())
                ensure(task.completionCallCount).stays(1)
            }

            it("should turn async in to sync") {
                let task = AsyncTaskSpy { () -> Int in
                    sleep(for: .milliseconds(1))
                    return 3
                }
                let value = try! task.await()
                expect(value).to(equal(3))
                ensure(task.completionCallCount).stays(1)
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
                ensure(task.completionCallCount).stays(1)
            }

//            it("should call completion on specified queue") {
//                let queue = DispatchQueue(label: "Swooft.Tests.AsyncTask")
//                let key = DispatchSpecificKey<Void>()
//                queue.setSpecific(key: key, value: ())
//                let task = AsyncTaskSpy {
//                    expect(DispatchQueue.getSpecific(key: key)).toNot(beNil())
//                }
//                _ = try! task.await(queue: queue)
//            }
        }
    }
}
