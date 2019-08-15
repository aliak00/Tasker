import Foundation
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

extension Result {
    var failureValue: Failure? {
        switch self {
        case let .failure(value):
            return value
        default:
            return nil
        }
    }

    var successValue: Success? {
        switch self {
        case let .success(value):
            return value
        default:
            return nil
        }
    }
}

func sleep(for interval: DispatchTimeInterval) {
    switch interval {
    case let .microseconds(value):
        usleep(useconds_t(value))
    case let .milliseconds(value):
        usleep(useconds_t(1000 * value))
    case let .nanoseconds(value):
        var requiredTimespec = timespec(tv_sec: 0, tv_nsec: value)
        withUnsafePointer(to: &requiredTimespec) { ptr in
            let actualTimespecPointer = UnsafeMutablePointer<timespec>.init(bitPattern: 0)
            nanosleep(ptr, actualTimespecPointer)
        }
    case let .seconds(value):
        usleep(useconds_t(1000 * 1000 * value))
    case .never:
        break
    @unknown default:
        fatalError()
    }
}

func XCTAssertErrorEqual(_ e1: Error?, _ e2: Error?, line: UInt = #line, file: StaticString = #file) {
    XCTAssertEqual(e1 as NSError?, e2 as NSError?, "", file: file, line: line)
}
