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

    func interceptorShouldRerunTest(reintercept: Bool) {
        class MyTask: Task {
            var value: Int = 0
            var counter = AtomicInt(0)
            typealias SuccessValue = Int
            func execute(completion: @escaping (Result<Int, Error>) -> Void) {
                completion(.success(self.value))
            }
        }

        let interceptor = InterceptorSpy()
        interceptor.interceptBlock = { anyTask, _ in
            let task = anyTask as! MyTask
            task.value += 1
            return .execute
        }

        let reactor = ReactorSpy(configuration: ReactorConfiguration(requeuesTask: true, reinterceptOnRequeue: reintercept))
        reactor.shouldExecuteBlock = { _, anyTask, _ in
            let task = anyTask as! MyTask
            return task.value == 1 && task.counter.getAndIncrement() < 1
        }

        let manager = TaskManagerSpy(interceptors: [interceptor], reactors: [reactor])

        let count = 100
        for _ in 0 ..< count {
            manager.add(task: MyTask())
        }

        ensure(manager.completionCallCount).becomes(count)
        manager.completionCallData.data.forEach {
            XCTAssertEqual($0.successValue as! Int, reintercept ? 2 : 1)
        }
    }

    func testInterceptorShouldNotRunAfterReactorRequeues() {
        self.interceptorShouldRerunTest(reintercept: false)
    }

    func testInterceptorShouldRunAfterReactorRequeues() {
        self.interceptorShouldRerunTest(reintercept: true)
    }
}
