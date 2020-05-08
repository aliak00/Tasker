import Foundation

class AtomicInt: ExpressibleByIntegerLiteral {
    required init(integerLiteral value: Int) {
        self._value = value
    }

    fileprivate var queue = DispatchQueue(label: "Tasker.AtomicInt")
    fileprivate var _value = 0

    init() {}

    init(_ value: Int) {
        self._value = value
    }

    var value: Int {
        get {
            self.queue.sync {
                self._value
            }
        }

        set {
            self.queue.sync {
                self._value = newValue
            }
        }
    }

    @discardableResult
    func getAndIncrement() -> Int {
        self.queue.sync {
            let previousValue = self._value
            self._value += 1
            return previousValue
        }
    }

    @discardableResult
    func getAndDecrement() -> Int {
        self.queue.sync {
            let previousValue = self._value
            self._value -= 1
            return previousValue
        }
    }

    func add(_ number: Int) {
        self.queue.sync {
            self._value += number
        }
    }

    static func += (lhs: inout AtomicInt, rhs: Int) {
        lhs.add(rhs)
    }
}

extension AtomicInt: Equatable {
    static func == (lhs: AtomicInt, rhs: AtomicInt) -> Bool {
        lhs.queue.sync {
            lhs._value == rhs.value
        }
    }
}

extension AtomicInt: CustomStringConvertible {
    var description: String {
        "\(self.value)"
    }
}
