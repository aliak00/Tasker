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

public struct LinkedList<Element> {

    public typealias Node = LinkedListNode<Element>

    var head: Node?
    var tail: Node?
    var _count = 0

    public var count: Int {
        return self._count
    }

    @discardableResult
    public mutating func append(_ value: Element) -> Node {
        return self.append(Node(value))
    }

    @discardableResult
    public mutating func append(_ node: Node) -> Node {
        node.previous = self.head
        node.previous?.next = node
        self.head = node
        if self.tail == nil {
            self.tail = node
        }
        self._count += 1
        return node
    }

    @discardableResult
    public mutating func prepend(_ value: Element) -> Node {
        return self.prepend(Node(value))
    }

    @discardableResult
    public mutating func prepend(_ node: Node) -> Node {
        node.next = self.tail
        node.next?.previous = node
        self.tail = node
        if self.head == nil {
            self.head = node
        }
        self._count += 1
        return node
    }

    @discardableResult
    public mutating func remove(_ node: Node) -> Node? {
        if node === self.tail {
            return self.removeBack()
        } else if node === self.head {
            return self.removeFront()
        }
        node.previous?.next = node.next
        node.next?.previous = node.previous
        self._count -= 1
        return node
    }

    @discardableResult
    public mutating func removeBack() -> Node? {
        guard let last = self.tail else {
            return nil
        }
        self.tail = last.next
        self.tail?.previous = nil
        self._count -= 1
        return last
    }

    @discardableResult
    public mutating func removeFront() -> Node? {
        guard let head = self.head else {
            return nil
        }
        self.head = head.previous
        self.head?.next = nil
        self._count -= 1
        return head
    }
}

extension LinkedList: Sequence {
    public func makeIterator() -> LinkedListIterator<Element> {
        return LinkedListIterator(list: self)
    }
}

extension LinkedList: Collection {
    public typealias Index = LinkedListIndex<Element>
    public typealias Iterator = LinkedListIterator<Element>

    public func index(after i: Index) -> Index {
        return Index(node: i.node?.next)
    }

    public var startIndex: Index {
        return Index(node: self.tail)
    }

    public var endIndex: Index {
        return Index(node: self.head?.next)
    }

    public subscript(index: LinkedList<Element>.Index) -> Iterator.Element {
        guard let node = index.node else {
            fatalError("Index \(index) out of range")
        }
        return node.value
    }

    /**
     - complexity O(n)
     */
    public subscript(index: Int) -> Element? {
        get {
            var current = self.tail
            for i in 0..<self._count {
                guard i == index else {
                    current = current?.next
                    continue
                }
                return current?.value
            }
            return nil
        }
        set(element) {
            var currentIndex = 0
            var currentNode = self.tail

            while currentNode != nil {
                defer {
                    currentIndex += 1
                    currentNode = currentNode?.next
                }
                guard currentIndex == index else {
                    continue
                }
                guard let element = element else {
                    self.remove(currentNode!)
                    return
                }
                let newNode = Node(element)
                currentNode?.previous?.next = newNode
                currentNode?.next?.previous = newNode
                newNode.next = currentNode?.next
                newNode.previous = currentNode?.previous
            }
        }
    }
}

extension LinkedList: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        for element in elements {
            self.append(Node(element))
        }
    }
}

/**
 Returns true if both lists have same number of elements and they are all equal

 - complexity O(n)
 */
public func == <Element: Equatable>(lhs: LinkedList<Element>, rhs: LinkedList<Element>) -> Bool {
    guard lhs.count == rhs.count else {
        return false
    }
    var a = lhs.tail
    var b = rhs.tail
    while a != nil {
        guard a?.value == b?.value else {
            return false
        }
        a = a?.next
        b = b?.next
    }
    return true
}

extension LinkedList: CustomStringConvertible {
    public var description: String {
        var array: [Element] = []
        for e in self {
            array.append(e)
        }
        return array.description
    }
}
