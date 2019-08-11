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

    func testRequeingReactorsShouldReleaseAllHandlesAfterDone() {
        Logger.shared.addTransport({print($0)})
        let reactor = ReactorSpy(configuration: .init(timeout: nil, requeuesTask: true, suspendsTaskQueue: false))
        reactor.executeBlock = { _ in } // do nothing

        let manager = TaskReactorManagerSpy(reactors: [reactor])
        let delegate = TaskReactorDelegateSpy()
        manager.delegate = delegate

        // let handles queue
        let count = 10
        let handles = (0..<count).map { _ in manager.react() }

        ensure(reactor.executeCallCount).becomes(1)
        reactor.executeCallData.data.first?(nil) // release

        ensure(manager.completionCallCount).becomes(count)

        ensure(delegate.reactorsCompletedData.count).becomes(1)

        XCTAssertEqual(delegate.reactorsCompletedData.data.first, Set(handles))
    }

}
