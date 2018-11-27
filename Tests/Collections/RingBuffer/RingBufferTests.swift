@testable import Tasker
import XCTest

final class RingBufferTests: XCTestCase {
    func testRingBufferShouldWrapAppends() {
        var r1 = RingBuffer(elementsDictatingCapacity: [1, 2, 3])
        r1.append(4)
        let r2 = RingBuffer(elementsDictatingCapacity: [4, 2, 3])
        XCTAssertEqual(r1, r2)
    }

    func testRingBufferShouldProvideAccurateCount() {
        var r1 = RingBuffer<Int>(capacity: 10)
        XCTAssertEqual(r1.capacity, 10)
        r1.append(0)
        r1.append(0)
        XCTAssertEqual(r1.count, 2)
        let r2 = RingBuffer(elementsDictatingCapacity: [0, 0])
        XCTAssertEqual(r1, r2)
    }

    func testRingBufferShouldEqualAnotherSimilar() {
        let r1 = RingBuffer(elementsDictatingCapacity: [0, 1, 2])
        let r2 = RingBuffer(elementsDictatingCapacity: [0, 1, 2])
        XCTAssertEqual(r1, r2)
    }
}
