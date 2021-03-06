@testable import Tasker
import XCTest

class TaskManagerHandleTests: XCTestCase {
    override func setUp() {
        TaskManager.Handle.counter.value = 0
        self.addTeardownBlock {
            ensure(AsyncOperation.referenceCounter.value).becomes(0)
            AsyncOperation.referenceCounter.value = 0
        }
    }

    func testCancelShouldCancelATask() {
        let numHandles = 100

        let restartReactor = ReactorSpy(configuration: ReactorConfiguration(requeuesTask: true))
        restartReactor.shouldExecuteBlock = { _, _, _ in true }

        // We use a reactor so that if handlers finish before being cancelled we just requeue them
        let manager = TaskManagerSpy(reactors: [restartReactor])

        var handles: [Handle] = []
        for _ in 0 ..< numHandles {
            let handle = manager.add(task: kDummyTask)
            handles.append(handle)
        }

        for i in 0 ..< numHandles {
            handles[i].cancel()
        }

        ensure(manager.completionCallCount).becomes(numHandles)

        handles.forEach { handle in
            XCTAssertEqual(handle.state, TaskState.finished)
        }

        for i in 0 ..< numHandles {
            XCTAssertErrorEqual(TaskError.cancelled, manager.completionCallData[i].failureValue)
        }
    }

    func testStartShouldStartATask() {
        let manager = TaskManagerSpy()
        let handle = manager.add(task: kDummyTask, startImmediately: false)
        ensure(handle.state).stays(.pending)
        handle.start()
        ensure(handle.state).becomes(.finished)
    }
}
