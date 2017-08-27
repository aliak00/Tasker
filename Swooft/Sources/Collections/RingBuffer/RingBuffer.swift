/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

public struct RingBuffer<Element> {
    fileprivate var array: [Element] = []
    fileprivate var currentIndex = 0
    private let size: Int

    public init(size: Int) {
        self.size = size
        self.array.reserveCapacity(size)
    }

    public mutating func append(_ element: Element) {
        if self.array.count < self.size {
            self.array.append(element)
        } else {
            self.array[self.currentIndex % self.array.count] = element
            self.currentIndex += 1
        }
    }
}

public func == <Element>(lhs: RingBuffer<Element>, rhs: RingBuffer<Element>) -> Bool where Element: Equatable {
    return lhs.array == rhs.array
}

extension RingBuffer: Collection {
    public func index(after i: Int) -> Int {
        return i + 1
    }

    public var startIndex: Int {
        return 0
    }

    public var endIndex: Int {
        return self.array.count
    }

    public subscript(index: Int) -> Element {
        return self.array[(self.currentIndex + index) % self.array.count]
    }
}

extension RingBuffer: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: Element...) {
        self.init(size: elements.count)
        self.array = elements
    }
}

extension RingBuffer: CustomStringConvertible {
    public var description: String {
        return self.array.description
    }
}
