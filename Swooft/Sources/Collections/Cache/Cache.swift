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

public struct Cache<Key: Hashable, Value> {

    typealias List = LinkedList<Key>
    var queue = List()
    var store: [Key: (node: List.Node, value: Value)] = [:]

    let capacity: Int

    public init(desiredCapacity: Int, initialElements: [Key: Value]) {
        self.init(capacity: Swift.max(desiredCapacity, initialElements.count))
        for (key, value) in initialElements {
            self[key] = value
        }
    }

    public init(elementsDictatingCapacity: [Key: Value]) {
        self.init(desiredCapacity: elementsDictatingCapacity.count, initialElements: elementsDictatingCapacity)
    }

    public init(capacity: Int) {
        self.capacity = capacity
    }

    public subscript(key: Key) -> Value? {
        mutating get {
            guard let data = self.store[key] else {
                return nil
            }

            self.queue.remove(data.node)
            self.queue.append(data.node)
            return data.value
        }

        set(newValue) {
            guard let value = newValue else {
                if let data = self.store.removeValue(forKey: key) {
                    self.queue.remove(data.node)
                }
                return
            }

            if self.store.count >= self.capacity, let node = self.queue.removeBack() {
                self.store[node.value] = nil
            }
            self.store[key] = (node: self.queue.append(key), value: value)
        }
    }
}

extension Cache: CustomStringConvertible {
    public var description: String {
        var string = "["
        for (index, element) in self.store.enumerated() {
            string += "\(element.key): \(element.value.value)"
            if index + 1 < self.store.count {
                string += ", "
            }
        }
        string += "]"
        return string
    }
}
