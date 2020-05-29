@testable import Tasker
import XCTest

final class ArrayOfTasksTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(AsyncOperation.referenceCounter.value).becomes(0)
            AsyncOperation.referenceCounter.value = 0
        }
    }

    func testCanBeAwaited() {
        var tasks: [AnyTask<Int>] = []
        for i in 0 ..< 10 {
            tasks.append(AnyTask { i })
        }
        for (i, result) in (try! tasks.await()).sorted().enumerated() {
            XCTAssertEqual(i, result.successValue)
        }
    }

    func testEmptyArrayCanBeAwaited() {
        let tasks: [AnyTask<Int>] = []
        let results = try? tasks.await()
        XCTAssertEqual(results?.count, 0)
    }

    func testCanBeAsynced() {
        var tasks: [AnyTask<Int>] = []
        for i in 0 ..< 10 {
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

    func testAwaitSuccess() {
        var tasks: [AnyTask<Int>] = []
        for i in 0 ..< 10 {
            tasks.append(AnyTask {
                if i.isMultiple(of: 2) {
                    $0(.success(i))
                } else {
                    $0(.failure(NSError(domain: "", code: i, userInfo: nil)))
                }
            })
        }
        XCTAssertEqual(tasks.awaitSuccess(), [0, 2, 4, 6, 8])
    }
}
