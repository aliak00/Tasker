@testable import Tasker
import XCTest

final class FreeFunctionTaskTests: XCTestCase {
    func testShouldCreateTaskFromAutoClosure() {
        XCTAssertEqual(try! task(closingOver: 3).await(), 3)
    }

    func testShouldCreateTaskFromVoidDone() {
        let val = AtomicInt(0)
        let f: (() -> Void) -> Void = { done in
            val.value = 7
            done()
        }
        task(executing: f).async()
        ensure(val.value).becomes(7)
    }

    func testShouldCreateTaskForDoneReturningT() {
        let f: ((Int) -> Void) -> Void = { done in
            done(10)
        }
        XCTAssertEqual(try! task(executing: f).await(), 10)
    }

    func testShouldCreateTaskForResultReturningType() {
        let f: ((Result<Int, Error>) -> Void) -> Void = { done in
            done(.success(15))
        }
        XCTAssertEqual(try! task(executing: f).await(), 15)
    }
}
