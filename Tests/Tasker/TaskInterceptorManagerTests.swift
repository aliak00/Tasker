@testable import Tasker
import XCTest

private let kHandle = TaskManager.Handle()

class TaskInterceptorManagerTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(kTaskSpyCounter.value).becomes(0)
        }
    }

    func testNoInterceptorShouldDefaultToExecute() {
        let count = 10
        let interceptorManager = TaskInterceptorManagerSpy()
        for _ in 0..<count {
            interceptorManager.intercept(task: &kDummyTask, for: kHandle)
        }
        ensure(interceptorManager.completionCallCount).becomes(count)
        for i in 0..<count {
            ensure(interceptorManager.completionCallData.data[i]).becomes(.execute([kHandle]))
        }
    }

    func testBatchingInterceptorBatchesThenReleasesAll() {
        let maxBatchCount = 10;
        let interceptor = InterceptorSpy()
        interceptor.interceptBlock = { anyTask, currentBatchCount in
            return currentBatchCount < (maxBatchCount - 1) ? .hold : .execute
        }

        let interceptorManager = TaskInterceptorManagerSpy(interceptors: [interceptor])

        for _ in 0..<maxBatchCount {
            interceptorManager.intercept(task: &kDummyTask, for: kHandle)
        }

        ensure(interceptorManager.completionCallCount).becomes(maxBatchCount)

        XCTAssertEqual(
            Array(interceptorManager.completionCallData.data[0..<9]),
            Array(repeating: TaskInterceptorManager.InterceptionResult.ignore, count: 9)
        )

        XCTAssertEqual(
            interceptorManager.completionCallData.data.last,
            .execute(Array(repeating: kHandle, count: 10))
        )
    }

    func testDiscardingExecutesNoHandles() {
        let count = 10
        let interceptor = InterceptorSpy()
        interceptor.interceptBlock = { anyTask, currentBatchCount in
            return .discard
        }

        let interceptorManager = TaskInterceptorManagerSpy(interceptors: [interceptor])

        for _ in 0..<count {
            interceptorManager.intercept(task: &kDummyTask, for: kHandle)
        }
        ensure(interceptorManager.completionCallCount).becomes(count)

        XCTAssertEqual(
            Array(interceptorManager.completionCallData.data),
            Array(repeating: TaskInterceptorManager.InterceptionResult.ignore, count: count)
        )
    }

    func testForceExecuteShouldOverwiriteHold() {
        let holdInterceptor = InterceptorSpy()
        holdInterceptor.interceptBlock = { _, _ in
            return .hold
        }

        let forceInterceptor = InterceptorSpy()
        forceInterceptor.interceptBlock = { _, _ in
            return .forceExecute
        }

        let interceptorManager = TaskInterceptorManagerSpy(interceptors: [holdInterceptor, forceInterceptor])
        interceptorManager.intercept(task: &kDummyTask, for: kHandle)

        ensure(interceptorManager.completionCallData.data.first).becomes(.execute([kHandle]))
    }

    func testHoldShouldTakePrecedenceOnExecute() {
        let holdInterceptor = InterceptorSpy()
        holdInterceptor.interceptBlock = { _, _ in
            return .hold
        }

        let executeInterceptor = InterceptorSpy()
        executeInterceptor.interceptBlock = { _, _ in
            return .execute
        }

        let interceptorManager = TaskInterceptorManagerSpy(interceptors: [holdInterceptor, executeInterceptor])
        interceptorManager.intercept(task: &kDummyTask, for: kHandle)

        ensure(interceptorManager.completionCallData.data.first).becomes(.ignore)
    }

    func testDiscardShouldTakePrecedenceOnExecuteAndHold() {
        let holdInterceptor = InterceptorSpy()
        holdInterceptor.interceptBlock = { _, _ in
            return .hold
        }

        let executeInterceptor = InterceptorSpy()
        executeInterceptor.interceptBlock = { _, _ in
            return .execute
        }

        let discardInterceptor = InterceptorSpy()
        discardInterceptor.interceptBlock = { _, _ in
            return .discard
        }

        let interceptorManager = TaskInterceptorManagerSpy(interceptors: [holdInterceptor, executeInterceptor, discardInterceptor])
        interceptorManager.intercept(task: &kDummyTask, for: kHandle)

        ensure(interceptorManager.completionCallData.data.first).becomes(.ignore)
    }
}
