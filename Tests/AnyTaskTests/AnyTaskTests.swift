@testable import Tasker
import XCTest

final class AnyTaskTests: XCTestCase {
    func testThrowingFromAnyTaskWorks() {
        struct SomeError: Error {}
        let error: Void? = try? AnyTask { throw SomeError() }.await()
        XCTAssertTrue(error == nil)
        let value = try? AnyTask { 3 }.await()
        XCTAssertEqual(value, 3)
    }

    func testShouldExecutePassedInTask() {
        let numTasks = 20
        let task = TaskSpy { $0(.success(())) }
        for _ in 0 ..< numTasks {
            AnyTask(fromTask: task).async()
        }
        ensure(task.executeCallCount).becomes(numTasks)
    }

    func testHandlesErrorsAndSuccessCompletions() {
        typealias Task = AnyTask<Int>
        let results = SynchronizedArray<Task.Result>()
        for i in 0 ..< 10 {
            Task { completion in
                sleep(for: .milliseconds(1))
                if i.isMultiple(of: 2) {
                    completion(.success(i))
                } else {
                    completion(.failure(NSError(domain: "", code: i, userInfo: nil)))
                }
            }.async { result in
                results.append(result)
            }
        }

        ensure(results.count).becomes(10)

        for (i, result) in results.data.sorted().enumerated() {
            if i.isMultiple(of: 2) {
                XCTAssertEqual(result.successValue, i)
            } else {
                XCTAssertEqual((result.failureValue as NSError?)?.code, i)
            }
        }
    }

    func testAnyTaskAsyncHandles() {
        let semaphore = DispatchSemaphore(value: 0)
        let stateInside = Atomic<TaskState>(.pending)
        let handle = Atomic<Handle?>(nil)
        handle.value = AnyTask {
            if let state = handle.value?.state {
                stateInside.value = state
            }
            semaphore.signal()
        }.async()
        semaphore.wait()
        XCTAssertEqual(stateInside.value, .executing)
        ensure(handle.value?.state).becomes(.finished)
    }
}
