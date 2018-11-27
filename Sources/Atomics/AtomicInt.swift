import Foundation

public struct AtomicInt: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self._value = value
    }

    fileprivate var queue = DispatchQueue(label: "Tasker.AtomicInt")
    fileprivate var _value = 0

    public init() {}

    public init(_ value: Int) {
        self._value = value
    }

    public var value: Int {
        get {
            var value: Int = 0
            self.queue.sync {
                value = self._value
            }
            return value
        }

        set {
            self.queue.sync {
                self._value = newValue
            }
        }
    }

    @discardableResult
    public mutating func getAndIncrement() -> Int {
        var previousValue = 0
        self.queue.sync {
            previousValue = self._value
            self._value += 1
        }
        return previousValue
    }

    @discardableResult
    public mutating func getAndDecrement() -> Int {
        var previousValue = 0
        self.queue.sync {
            previousValue = self._value
            self._value -= 1
        }
        return previousValue
    }

    public mutating func add(_ number: Int) {
        self.queue.sync {
            self._value += number
        }
    }

    public static func += (lhs: inout AtomicInt, rhs: Int) {
        lhs.add(rhs)
    }
}

extension AtomicInt: Equatable {
    ///
    public static func == (lhs: AtomicInt, rhs: AtomicInt) -> Bool {
        return lhs.queue.sync {
            lhs._value == rhs.value
        }
    }
}
