@testable import Tasker
import XCTest

final class AnyTaskTests: XCTestCase {
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
}
