@testable import Tasker
import XCTest

final class TaskerTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        let a = Tasker.Result<Int>.success(3)
        XCTAssertEqual(a.successValue!, 3)
    }
}
