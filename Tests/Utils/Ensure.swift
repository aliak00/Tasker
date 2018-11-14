import Foundation
import XCTest

/*
 These are here because of me thinks a bug inside expect(blah).toEventually(blah), or not
 a bug but something related to caching or memoization

 If you run the following code then DEINIT will never be printed and if you change the
 toEventually to just 'to' then it will print as expected.

 ```
 class Test {
     let i = 5
     init() {
         print("INIT")
     }
     deinit {
         print("DEINIT")
     }
 }

 class TestTests: QuickSpec {
     override func spec() {
         it("testing eventually") {
             let test = Test()
             expect(test.i).toEventually(equal(5))
         }
     }
 }

 ```
 */

struct Ensure<T: Equatable> {
    let block: () -> T?
    let line: UInt
    let file: StaticString

    init(line: UInt, file: StaticString, block: @escaping () -> T?) {
        self.block = block
        self.line = line
        self.file = file
    }

    func becomes(_ value: T, timeout: DispatchTimeInterval = .seconds(1)) {
        var lastValue = self.block()
        var passed = lastValue == value
        let start = DispatchTime.now()
        while DispatchTime.now() < start + timeout && !passed {
            sleep(for: .milliseconds(1))
            lastValue = self.block()
            passed = lastValue == value
        }
        if !passed {
            var string = "nil"
            if let lastValue = lastValue {
                string = "\(lastValue)"
            }
            XCTFail("expected \(value), got \(string)", file: self.file, line: self.line)
        }
    }

    func stays(_ value: T, for interval: DispatchTimeInterval = .milliseconds(100)) {
        var lastValue = self.block()
        var passed = lastValue == value
        let start = DispatchTime.now()
        while DispatchTime.now() < start + interval && passed {
            sleep(for: .milliseconds(1))
            lastValue = self.block()
            passed = lastValue == value
        }
        if lastValue != value {
            var string = "nil"
            if let lastValue = lastValue {
                string = "\(lastValue)"
            }
            XCTFail("expected to remain \(value), but became \(string)", file: self.file, line: self.line)
        }
    }
}

func ensure<T: Equatable>(_ block: @escaping @autoclosure () -> T?, _ line: UInt = #line, _ file: StaticString = #file) -> Ensure<T> {
    return Ensure(line: line, file: file, block: block)
}
