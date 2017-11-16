//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Quick
import Nimble

@testable import Swooft

class AsyncAwaitTests: QuickSpec {

    override func spec() {

        it("should work") {
            let task = AsyncAwaitSpy { () -> Int in
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
            ensure(task.completionCallData.first?.successValue).becomes(3)
        }

        describe("async") {

            it("should call execute") {
                let task = AsyncAwaitSpy {}
                task.async()
                ensure(task.completionCallCount).becomes(1)
            }

            it("should get cancelled error") {
                let task = AsyncAwaitSpy { sleep(for: .milliseconds(5)) }
                let handle = task.async()
                handle.cancel()
                ensure(task.completionCallCount).becomes(1)
                expect(task.completionCallData.first).to(failWith(TaskError.cancelled))
            }

            it("should timeout after deadline reached") {
                let task = AsyncAwaitSpy { sleep(for: .milliseconds(5)) }
                let handle = task.async(timeout: .milliseconds(1))
                ensure(task.completionCallCount).becomes(1)
                expect(task.completionCallData.first).to(failWith(TaskError.timedOut))
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
                let task = AsyncAwaitSpy { true }
                let value = try! task.await()
                expect(value).to(beTrue())
                ensure(task.completionCallCount).stays(1)
            }

            it("should turn async in to sync") {
                let task = AsyncAwaitSpy { () -> Int in
                    sleep(for: .milliseconds(1))
                    return 3
                }
                let value = try! task.await()
                expect(value).to(equal(3))
                ensure(task.completionCallCount).stays(1)
            }

            it("should timeout after deadline reached") {
                let task = AsyncAwaitSpy { sleep(for: .milliseconds(5)) }
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
