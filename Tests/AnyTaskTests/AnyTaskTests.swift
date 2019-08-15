@testable import Tasker
import XCTest

extension Array where Element == Result<Int, Error> {
    func sorted() -> [Result<Int, Error>] {
        return self.sorted { (a, b) -> Bool in
            let ai = a.successValue ?? (a.failureValue as NSError?)!.code
            let bi = b.successValue ?? (b.failureValue as NSError?)!.code
            return ai < bi
        }
    }
}

final class AnyTaskTests: XCTestCase {
    func testShouldExecutePassedInTask() {
        let numTasks = 20
        let task = TaskSpy { $0(.success(())) }
        for _ in 0..<numTasks {
            AnyTask(fromTask: task).async()
        }
        ensure(task.executeCallCount).becomes(numTasks)
    }

    func testHandlesErrorsAndSuccessCompletions() {
        typealias Task = AnyTask<Int>
        let results = SynchronizedArray<Task.Result>()
        for i in 0..<10 {
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

    func testArrayOfTasksCanBeAwaited() {
        var tasks: [AnyTask<Int>] = []
        for i in 0..<10 {
            tasks.append(AnyTask { i })
        }
        for (i, result) in (try! tasks.await()).sorted().enumerated() {
            XCTAssertEqual(i, result.successValue)
        }
    }

    func testArrayOfTasksCanBeAsynced() {
        var tasks: [AnyTask<Int>] = []
        for i in 0..<10 {
            tasks.append(AnyTask {
                if i.isMultiple(of: 2) {
                    $0(.success(i))
                } else {
                    $0(.failure(NSError(domain: "", code: i, userInfo: nil)))
                }
            })
        }
        let result = SynchronizedArray<Result<Int, Error>>()
        tasks.async {
            if let data = $0.successValue {
                result.data = data
            }
        }

        ensure(result.count).becomes(10)
        for (i, result) in result.data.sorted().enumerated() {
            if i.isMultiple(of: 2) {
                XCTAssertEqual(i, result.successValue)
            } else {
                XCTAssertEqual(i, (result.failureValue as NSError?)?.code)
            }
        }
    }
}
