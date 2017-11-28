//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Nimble
import Quick
@testable import Swooft

class AsyncOperationTests: QuickSpec {

    override func spec() {

        describe("creating operation") {

            it("should start in ready state") {
                let operation = AsyncOperationSpy { _ in }
                expect(operation.state) == AsyncOperation.State.ready
            }
        }

        describe("starting operation") {

            it("should go to executing") {
                let operation = AsyncOperationSpy { _ in }
                operation.start()
                ensure(operation.state).becomes(.executing)
            }

            it("should call executor") {
                let operation = AsyncOperationSpy { _ in }
                operation.start()
                ensure(operation.executorCallCount).becomes(1)
            }

            it("should go to finished") {
                let operation = AsyncOperation { $0.finish() }
                operation.start()
                ensure(operation.state).becomes(.finished)
            }
        }

        describe("adding operations to a queue") {

            it("should all go to finished") {
                let queue = OperationQueue()
                var operations: [AsyncOperation] = []
                for _ in 0..<100 {
                    operations.append(AsyncOperation { $0.finish() })
                }
                queue.addOperations(operations, waitUntilFinished: true)
                operations.forEach { expect($0.state) == AsyncOperation.State.finished }
            }

            it("should all go to finished if cancelled") {
                let queue = OperationQueue()
                var operations: [AsyncOperation] = []
                for _ in 0..<100 {
                    operations.append(AsyncOperation { _ in })
                }
                operations.forEach { $0.cancel() }
                queue.addOperations(operations, waitUntilFinished: false)
                operations.forEach { ensure($0.state).becomes(.finished) }
            }
        }

        describe("cancelling before") {

            it("before starting should not call executor") {
                let operation = AsyncOperationSpy { _ in }
                operation.cancel()
                operation.start()
                ensure(operation.executorCallCount).stays(0)
                expect(operation.state) == AsyncOperation.State.finished
            }

            it("before starting should not call finish") {
                let operation = AsyncOperationSpy { _ in }
                operation.cancel()
                operation.start()
                ensure(operation.finishCallCount).stays(0)
                expect(operation.state) == AsyncOperation.State.finished
            }
        }

        describe("cancelling after") {

            it("executing should call finish") {
                let operation = AsyncOperationSpy { _ in }
                operation.start()
                ensure(operation.state).becomes(.executing)
                operation.cancel()
                ensure(operation.state).becomes(.finished)
            }
        }
    }
}
