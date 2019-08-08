@testable import Tasker
import XCTest

class TaskHandleTests: XCTestCase {
    override func setUp() {
        TaskManager.Handle.counter.value = 0
        self.addTeardownBlock {
            ensure(AsyncOperation.identifierCounter.value).becomes(0)
            AsyncOperation.identifierCounter.value = 0
        }
    }

    func testCancelShouldCancelATask() {
        let numHandles = 100

        let restartReactor = ReactorSpy(configuration: TaskReactorConfiguration(requeuesTask: true))
        restartReactor.shouldExecuteBlock = { _, _, _ in true }

        // We use a reactor so that if handlers finish before being cancelled we just requeue them
        let manager = TaskManagerSpy(reactors: [restartReactor])

        var handles: [TaskHandle] = []
        for _ in 0..<numHandles {
            let handle = manager.add(task: kDummyTask)
            handles.append(handle)
        }

        for i in 0..<numHandles {
            handles[i].cancel()
        }

        ensure(manager.completionCallCount).becomes(numHandles)

        handles.forEach { handle in
            XCTAssertEqual(handle.state, TaskState.finished)
        }

        for i in 0..<numHandles {
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
