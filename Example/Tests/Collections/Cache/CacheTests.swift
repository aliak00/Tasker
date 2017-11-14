//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Quick
import Nimble
@testable import Swooft

func == <Key, Value: Equatable>(lhs: Cache<Key, Value>, rhs: Cache<Key, Value>) -> Bool {
    guard lhs.lru.count == rhs.lru.count else {
        return false
    }
    for key in lhs.lru {
        guard lhs.store[key]?.value == rhs.store[key]?.value else {
            return false
        }
    }
    return true
}

func equal<K, V: Equatable>(_ expected: Cache<K, V>) -> Predicate<Cache<K, V>> {
    return Predicate.simple("equal \(expected)") { expression in
        guard let actual = try expression.evaluate() else {
            return .doesNotMatch
        }
        return PredicateStatus(bool: expected == actual)
    }
}

func == <K, V: Equatable>(lhs: Expectation<Cache<K, V>>, rhs: Cache<K, V>) {
    lhs.to(equal(rhs))
}

class CacheTests: QuickSpec {

    override func spec() {

        describe("subscript set") {

            it("should set elements") {
                let cache = Cache<Int, Int>(capacity: 2)
                cache[0] = 10
                cache[1] = 20
                expect(cache) == Cache(elementsDictatingCapacity: [0: 10, 1: 20])
            }

            it("should ensure removal last accessed element") {
                let cache = Cache<Int, Int>(capacity: 2)
                cache[0] = 10
                cache[1] = 20
                cache[2] = 30
                expect(cache) == Cache(elementsDictatingCapacity: [1: 20, 2: 30])
            }
        }

        describe("subscript get") {

            it("should get elements") {
                let cache = Cache(elementsDictatingCapacity: [0: 10, 1: 20])
                expect(cache[0]) == 10
                expect(cache[1]) == 20
                expect(cache[2]).to(beNil())
            }

            it("should ensure removal last accessed element") {
                let cache = Cache(elementsDictatingCapacity: [0: 10, 1: 20])
                _ = cache[0]
                _ = cache[1]
                cache[2] = 30
                expect(cache) == Cache(elementsDictatingCapacity: [1: 20, 2: 30])
            }
        }
    }
}
