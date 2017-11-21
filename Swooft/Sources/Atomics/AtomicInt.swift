//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

public struct AtomicInt {
    fileprivate var queue = DispatchQueue(label: "Swooft.AtomicInt")
    fileprivate var _value = 0

    public init() {}

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
}

extension AtomicInt: Equatable {
    ///
    public static func == (lhs: AtomicInt, rhs: AtomicInt) -> Bool {
        return lhs.queue.sync {
            lhs._value == rhs.value
        }
    }
}
