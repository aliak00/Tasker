@testable import Tasker
import XCTest

private let kHandle = TaskManager.Handle()

class ReactorManagerTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(kTaskSpyCounter.value).becomes(0)
        }
    }

    func testNoReactorsShouldCallCompletionWithNoReactors() {
        let count = 10
        let reactorManager = ReactorManagerSpy()
        for _ in 0 ..< count {
            reactorManager.react()
        }
        ensure(reactorManager.completionCallCount).becomes(count)

        for i in 0 ..< count {
            let a = reactorManager.completionCallData.data[i]
            let b = ReactorManager.ReactionResult(requeueTask: false, suspendQueue: false)
            XCTAssertEqual(a, b)
        }
    }

    func testRequeingReactorsShouldReleaseAllHandlesAfterDone() {
        let reactor = ReactorSpy(configuration: .init(timeout: nil, requeuesTask: true, suspendsTaskQueue: false))
        reactor.executeBlock = { _ in } // do nothing

        let manager = ReactorManagerSpy(reactors: [reactor])
        let delegate = ReactorManagerDelegateSpy()
        manager.delegate = delegate

        // let handles queue
        let count = 10
        let handles = (0 ..< count).reduce(into: [TaskManager.Handle: ReactorManager.RequeueData]()) { dict, _ in
            dict[manager.react()] = ReactorManager.RequeueData(reintercept: false)
        }

        ensure(reactor.executeCallCount).becomes(1)
        reactor.executeCallData.data.first?(nil) // release

        ensure(manager.completionCallCount).becomes(count)

        ensure(delegate.reactorsCompletedData.count).becomes(1)

        XCTAssertEqual(delegate.reactorsCompletedData.data.first, handles)
    }
}
