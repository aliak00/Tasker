@testable import Tasker
import XCTest

final class AsyncOperationTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(AsyncOperation.identifierCounter.value).becomes(0)
            AsyncOperation.identifierCounter.value = 0
        }
    }

    func testCreatingOperationShouldStartInPendingState() {
        let operation = AsyncOperationSpy { _ in }
        XCTAssertEqual(operation.state, AsyncOperation.State.pending)
    }

    func testMarkingOperationReadyShouldGoToReadyState() {
        let operation = AsyncOperationSpy { _ in }
        operation.markReady()
        XCTAssertEqual(operation.state, AsyncOperation.State.ready)
    }

    func testStartingOperationShouldGoToExecuting() {
        let operation = AsyncOperationSpy { _ in }
        operation.markReady()
        operation.start()
        ensure(operation.state).becomes(.executing)
    }

    func testStartingOperationShouldCallExecutor() {
        let operation = AsyncOperationSpy { _ in }
        operation.markReady()
        operation.start()
        ensure(operation.executorCallCount).becomes(1)
    }

    func testStartingOperationShouldGoToFinished() {
        let operation = AsyncOperation { $0.finish() }
        operation.markReady()
        operation.start()
        ensure(operation.state).becomes(.finished)
    }

    func testAddingOperationsToAQueueShouldAllGoToFinished() {
        let queue = OperationQueue()
        var operations: [AsyncOperation] = []
        for _ in 0..<100 {
            operations.append(AsyncOperation { $0.finish() })
        }
        operations.forEach { $0.markReady()  }
        queue.addOperations(operations, waitUntilFinished: true)
        operations.forEach { XCTAssertEqual($0.state, AsyncOperation.State.finished) }
    }

    func testCancellingBeforeStartingShouldNotCallExecutor() {
        let operation = AsyncOperationSpy { $0.finish() }
        operation.markReady()
        operation.cancel()
        operation.start()
        ensure(operation.executorCallCount).stays(0)
        XCTAssertEqual(operation.state, AsyncOperation.State.finished)
    }

    func testCancellingBeforeStartingShouldNotCallFinish() {
        let operation = AsyncOperationSpy { $0.finish() }
        operation.cancel()
        operation.start()
        XCTAssertEqual(operation.finishCallCount, 0)
        XCTAssertEqual(operation.state, AsyncOperation.State.finished)
    }

    func testStartingAndCancellingManyTasksShouldWork() {
        let queue = OperationQueue()
        var operations: [AsyncOperation] = []
        let numTasks = 100
        for _ in 0..<numTasks {
            let operation = AsyncOperationSpy { $0.finish() }
            operations.append(operation)
            queue.addOperation(operation)
        }
        operations.forEach { XCTAssertEqual($0.state, AsyncOperation.State.pending) }
        operations.forEach { $0.markReady() }
        operations.forEach { $0.cancel() }
        queue.waitUntilAllOperationsAreFinished()
        operations.forEach { XCTAssertEqual($0.state, AsyncOperation.State.finished) }
    }
}
