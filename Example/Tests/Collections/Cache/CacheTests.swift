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

import Quick
import Nimble
@testable import Swooft


func == <Key: Hashable, Value: Equatable>(lhs: Cache<Key, Value>, rhs: Cache<Key, Value>) -> Bool {
    guard lhs.queue.count == rhs.queue.count else {
        return false
    }
    for key in lhs.queue {
        guard lhs.store[key]?.value == rhs.store[key]?.value else {
            return false
        }
    }
    return true
}

func equal<K: Hashable, V: Equatable>(_ expected: Cache<K, V>) -> Predicate<Cache<K, V>> {
    return Predicate.simple("equal \(expected)") { expression in
        guard let actual = try expression.evaluate() else {
            return .doesNotMatch
        }
        return PredicateStatus(bool: expected == actual)
    }
}

func == <K: Hashable, V: Equatable>(lhs: Expectation<Cache<K, V>>, rhs: Cache<K, V>) {
    lhs.to(equal(rhs))
}

class CacheTests: QuickSpec {

    override func spec() {

        describe("subscript set") {

            it("should set elements") {
                var cache = Cache<Int, Int>(capacity: 2)
                cache[0] = 10
                cache[1] = 20
                expect(cache) == Cache(elementsDictatingCapacity: [0: 10, 1: 20])
            }

            it("should ensure removal last accessed element") {
                var cache = Cache<Int, Int>(capacity: 2)
                cache[0] = 10
                cache[1] = 20
                cache[2] = 30
                expect(cache) == Cache(elementsDictatingCapacity: [1: 20, 2: 30])
            }
        }

        describe("subscript get") {

            it("should get elements") {
                var cache = Cache(elementsDictatingCapacity: [0: 10, 1: 20])
                expect(cache[0]) == 10
                expect(cache[1]) == 20
                expect(cache[2]).to(beNil())
            }

            it("should ensure removal last accessed element") {
                var cache = Cache(elementsDictatingCapacity: [0: 10, 1: 20])
                _ = cache[0]
                _ = cache[1]
                cache[2] = 30
                expect(cache) == Cache(elementsDictatingCapacity: [1: 20, 2: 30])
            }
        }
    }
}
