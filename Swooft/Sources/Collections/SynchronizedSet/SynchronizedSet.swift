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

public class SynchronizedSet<Element: Hashable> {
    var set = Set<Element>()
    let queue = DispatchQueue(label: "Swooft.Collections.SynchronizedSet", attributes: [.concurrent])

    public init() {}

    @discardableResult
    public func insert(_ newMember: Element) -> (inserted: Bool, memberAfterInsert: Element) {
        return self.queue.sync(flags: .barrier) {
            self.set.insert(newMember)
        }
    }

    @discardableResult
    public func remove(_ member: Element) -> Element? {
        return self.queue.sync {
            self.set.remove(member)
        }
    }

    public var count: Int {
        return self.queue.sync {
            self.set.count
        }
    }

    @discardableResult
    public func getAndMutate(mutator: (Set<Element>) -> Set<Element>) -> Set<Element> {
        return self.queue.sync(flags: .barrier) {
            self.set = mutator(self.set)
            return self.set
        }
    }

    public func takeAll() -> [Element] {
        return self.queue.sync {
            Array(self.set)
        }
    }
}
