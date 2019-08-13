import Foundation

class Atomic<T> {
    fileprivate var queue = DispatchQueue(label: "Tasker.Atomic<\(T.self)>")
    fileprivate var _value: T

    init(_ value: T) {
        self._value = value
    }

    var value: T {
        get {
            return self.queue.sync {
                self._value
            }
        }

        set {
            self.queue.sync {
                self._value = newValue
            }
        }
    }

    func transform<R>(tranformer: (inout T) -> R) -> R {
        return self.queue.sync {
            tranformer(&_value)
        }
    }

    func run(block: (inout T) -> Void) {
        self.queue.sync {
            block(&_value)
        }
    }

    @discardableResult
    func getAnd(set: (inout T) -> Void) -> T {
        return self.queue.sync {
            let previousValue = self._value
            set(&self._value)
            return previousValue
        }
    }
}

extension Atomic: Equatable where T: Equatable {
    static func == (lhs: Atomic, rhs: Atomic) -> Bool {
        return lhs.queue.sync {
            rhs.queue.sync {
                lhs._value == rhs._value
            }
        }
    }
}

extension Atomic: CustomStringConvertible {
    var description: String {
        return "\(self.value)"
    }
}
