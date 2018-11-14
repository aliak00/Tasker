import Tasker
import XCTest

// This interceptor will take any task that is retriable, and re-execute it
class BatchingInterceptor: TaskInterceptor {
    func intercept<T: Task>(task _: inout T, currentBatchCount: Int) -> InterceptCommand {
        return currentBatchCount < 9 ? .hold : .execute
    }
}

class ScenarioBatchingTests: XCTestCase {
    override func tearDown() {
        ensure(kTaskSpyCounter.value).becomes(0)
    }

    func testShouldAllWork() {
        let manager = TaskManagerSpy(interceptors: [BatchingInterceptor()])
        for i in 0..<9 {
            manager.add(task: TaskSpy { $0(.success(i)) })
        }
        ensure(manager.completionCallCount).stays(0)
        manager.add(task: TaskSpy { $0(.success(())) })
        ensure(manager.completionCallCount).becomes(10)
    }
}
