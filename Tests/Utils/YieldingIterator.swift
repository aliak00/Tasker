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
        YieldingIterator(yieldInterval: yieldInterval, base: self.makeIterator())
    }
}
