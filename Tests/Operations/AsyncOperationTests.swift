@testable import Tasker
import XCTest

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
        XCTAssertEqual(operation.finishCallCount, 1)
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
