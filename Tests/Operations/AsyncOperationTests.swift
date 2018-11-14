//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import XCTest
@testable import Tasker

final class AsyncOperationTests: XCTestCase {

    func testCreatingOperationShouldStartInReadyState() {
        let operation = AsyncOperationSpy { _ in }
        XCTAssertEqual(operation.state, AsyncOperation.State.ready)
    }

    func testStartingOperationShouldGoToExecuting() {
        let operation = AsyncOperationSpy { _ in }
        operation.start()
        ensure(operation.state).becomes(.executing)
    }

    func testStartingOperationShouldCallExecutor() {
        let operation = AsyncOperationSpy { _ in }
        operation.start()
        ensure(operation.executorCallCount).becomes(1)
    }

    func testStartingOperationShouldGoToFinished() {
        let operation = AsyncOperation { $0.finish() }
        operation.start()
        ensure(operation.state).becomes(.finished)
    }

    func testAddingOperationsToAQueueShouldAllGoToFinished() {
        let queue = OperationQueue()
        var operations: [AsyncOperation] = []
        for _ in 0..<100 {
            operations.append(AsyncOperation { $0.finish() })
        }
        queue.addOperations(operations, waitUntilFinished: true)
        operations.forEach { XCTAssertEqual($0.state, AsyncOperation.State.finished) }
    }

    func testAddingOperationsToAQueueShouldAllGoToFinishedIfCancelled() {
        let queue = OperationQueue()
        var operations: [AsyncOperation] = []
        for _ in 0..<100 {
            operations.append(AsyncOperation { _ in })
        }
        operations.forEach { $0.cancel() }
        queue.addOperations(operations, waitUntilFinished: false)
        operations.forEach { ensure($0.state).becomes(.finished) }
    }

    func testCancellingBeforeBeforeStartingShouldNotCallExecutor() {
        let operation = AsyncOperationSpy { _ in }
        operation.cancel()
        operation.start()
        ensure(operation.executorCallCount).stays(0)
        XCTAssertEqual(operation.state, AsyncOperation.State.finished)
    }

    func testCancellingBeforeBeforeStartingShouldNotCallFinish() {
        let operation = AsyncOperationSpy { _ in }
        operation.cancel()
        operation.start()
        ensure(operation.finishCallCount).stays(0)
        XCTAssertEqual(operation.state, AsyncOperation.State.finished)
    }

    func testCancellingAfterExecutingShouldCallFinish() {
        let operation = AsyncOperationSpy { _ in }
        operation.start()
        ensure(operation.state).becomes(.executing)
        operation.cancel()
        ensure(operation.state).becomes(.finished)
    }
}
