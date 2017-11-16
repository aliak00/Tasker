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

class AsyncOperationTests: QuickSpec {
    var queue = OperationQueue()
    override func spec() {

        beforeEach {
            self.queue = OperationQueue()
        }

        afterEach {
            waitUntil { done in
                self.queue.cancelAllOperations()
                self.queue.waitUntilAllOperationsAreFinished()
                done()
            }
        }

        describe("creating operation") {

            it("should start in ready state") {
                let operation = Swooft.AsyncOperation { _ in }
                expect(operation.state) == Swooft.AsyncOperation.State.ready
            }
        }

        describe("adding operation") {

            it("should go to executing if marked as ready") {
                let operation = Swooft.AsyncOperation { _ in }
                self.queue.addOperation(operation)
                ensure(operation.state).becomes(.executing)
            }

            it("should go to finished if marked finished") {
                let operation = Swooft.AsyncOperation { $0.finish() }
                self.queue.addOperation(operation)
                ensure(operation.state).becomes(.finished)
            }
        }

        describe("cancelling") {

            it("before adding should go to finished") {
                var executed = false
                let operation = Swooft.AsyncOperation { _ in executed = true }
                operation.cancel()
                self.queue.addOperation(operation)
                ensure(operation.state).becomes(.finished)
                expect(executed) == false
            }
        }
    }
}
