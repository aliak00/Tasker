@testable import Tasker
import XCTest

final class AnyTaskTests: XCTestCase {
    func testShouldExecutePassedInTask() {
        let numTasks = 20
        let task = TaskSpy { $0(.success(())) }
        for _ in 0..<numTasks {
            AnyTask(fromTask: task).async()
        }
        ensure(task.executeCallCount).becomes(numTasks)
    }
}
