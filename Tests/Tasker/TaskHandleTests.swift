@testable import Tasker
import XCTest

class TaskHandleTests: XCTestCase {
    override func setUp() {
        TaskManager.Handle.counter.value = 0
    }

    override func tearDown() {
        ensure(AsyncOperation.identifierCounter.value).becomes(0)
        AsyncOperation.identifierCounter.value = 0
    }

    func testCancelShouldCancelATask() {
        Logger.shared.addTransport { print($0) }

        for j in 0..<1 {
            do {
                let numHandles = 1
                let manager = TaskManagerSpy()
                var handles: [TaskHandle] = []

                for _ in 0..<numHandles {
                    let handle = manager.add(task: kDummyTask)
                    handles.append(handle)
                    handle.cancel()
                }
                handles.forEach { handle in
                    XCTAssertEqual(handle.state, TaskState.finished)
                }

                ensure(manager.completionCallCount).becomes(numHandles)

                for i in 0..<numHandles {
                    XCTAssertErrorEqual(TaskError.cancelled, manager.completionCallData[i].failureValue)
                }
            }
            //            print("done \(j)")
            ensure(AsyncOperation.identifierCounter.value).becomes(0)
            AsyncOperation.identifierCounter.value = 0
        }
        Logger.shared.removeTransports()
    }

    func testStartShouldStartATask() {
        let manager = TaskManagerSpy()
        let handle = manager.add(task: kDummyTask, startImmediately: false)
        ensure(handle.state).stays(.pending)
        handle.start()
        ensure(handle.state).becomes(.finished)
    }
}
