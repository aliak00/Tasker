@testable import Tasker
import XCTest

private let kHandle = TaskManager.Handle()

class TaskReactorManagerTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(kTaskSpyCounter.value).becomes(0)
        }
    }

    func testNoReactorsShouldCallCompletionWithNoReactors() {
        let count = 10
        let reactorManager = TaskReactorManagerSpy()
        for _ in 0..<count {
            reactorManager.react()
        }
        ensure(reactorManager.completionCallCount).becomes(count)

        for i in 0..<count {
            let a = reactorManager.completionCallData.data[i]
            let b = TaskReactorManager.ReactionResult(requeueTask: false, suspendQueue: false)
            XCTAssertEqual(a, b)
        }
    }

}
