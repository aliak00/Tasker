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

public struct LinkedListIndex<Element>: Comparable {
    let node: LinkedListNode<Element>?
    init(node: LinkedListNode<Element>?) {
        self.node = node
    }

    public static func < (lhs: LinkedListIndex, rhs: LinkedListIndex) -> Bool {
        guard let next = lhs.node?.next else {
            return false
        }
        return next === rhs.node
    }

    public static func == (lhs: LinkedListIndex, rhs: LinkedListIndex) -> Bool {
        return lhs.node === rhs.node
    }
}
