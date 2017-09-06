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

public class Cache<Key: Hashable, Value> {

    typealias List = LinkedList<Key>
    var lru = List()
    var store: [Key: (node: List.Node, value: Value)] = [:]
    let queue = DispatchQueue(label: "Swooft.Cache")

    let capacity: Int

    public convenience init(desiredCapacity: Int, initialElements: [Key: Value]) {
        self.init(capacity: Swift.max(desiredCapacity, initialElements.count))
        for (key, value) in initialElements {
            self[key] = value
        }
    }

    public convenience init(elementsDictatingCapacity: [Key: Value]) {
        self.init(desiredCapacity: elementsDictatingCapacity.count, initialElements: elementsDictatingCapacity)
    }

    public init(capacity: Int) {
        self.capacity = capacity
    }

    // Not thread safe
    private func setValue(_ value: Value?, forKey key: Key) {
        guard let value = value else {
            if let data = self.store.removeValue(forKey: key) {
                self.lru.remove(data.node)
            }
            return
        }

        if self.store.count >= self.capacity, let node = self.lru.removeBack() {
            self.store[node.value] = nil
        }
        self.store[key] = (node: self.lru.append(key), value: value)
    }

    public subscript(key: Key) -> Value? {
        get {
            return self.queue.sync {
                guard let data = self.store[key] else {
                    return nil
                }

                self.lru.remove(data.node)
                self.lru.append(data.node)
                return data.value
            }
        }

        set(newValue) {
            self.queue.async(flags: .barrier) { [weak self] in
                self?.setValue(newValue, forKey: key)
            }
        }
    }
}

extension Cache: CustomStringConvertible {
    public var description: String {
        let storeCopy = self.queue.sync {
            return self.store
        }
        var string = "["
        for (index, element) in storeCopy.enumerated() {
            string += "\(element.key): \(element.value.value)"
            if index + 1 < storeCopy.count {
                string += ", "
            }
        }
        string += "]"
        return string
    }
}
