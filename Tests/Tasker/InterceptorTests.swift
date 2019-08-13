@testable import Tasker
import XCTest

class InterceptorTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(kTaskSpyCounter.value).becomes(0)
        }
    }

    func testInterceptShouldBeCalledWithTask() {
        let interceptor = InterceptorSpy()
        let manager = TaskManagerSpy(interceptors: [interceptor])
        let task = TaskSpy { $0(.success(())) }
        manager.add(task: task)
        ensure(interceptor.interceptCallCount).becomes(1)
        XCTAssertTrue(interceptor.interceptCallData.data.first?.anyTask === task)
    }

    func testInterceptShouldModifyOriginalTask() {
        let interceptor = InterceptorSpy()
        interceptor.interceptBlock = { anyTask, _ in
            let task = anyTask as! TaskSpy<Void>
            task.executeCallBackData.append(AnyResult(Result<Int, Error>.success(1)))
            return .execute
        }
        let manager = TaskManagerSpy(interceptors: [interceptor])
        let task = TaskSpy { $0(.success(())) }
        manager.add(task: task)
        ensure(interceptor.interceptCallCount).becomes(1)
        ensure(task.executeCallCount).becomes(2)
    }
}
