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

struct YieldingIterator<Base>: IteratorProtocol, Sequence where Base: IteratorProtocol {
    var base: Base
    let yieldInterval: DispatchTimeInterval

    typealias Element = Base.Element

    init(yieldInterval: DispatchTimeInterval, base: Base) {
        self.base = base
        self.yieldInterval = yieldInterval
    }

    mutating func next() -> Element? {
        sleep(for: self.yieldInterval)
        return self.base.next()
    }
}

extension Sequence {
    func yielded(by yieldInterval: DispatchTimeInterval) -> YieldingIterator<Self.Iterator> {
        return YieldingIterator(yieldInterval: yieldInterval, base: self.makeIterator())
    }
}