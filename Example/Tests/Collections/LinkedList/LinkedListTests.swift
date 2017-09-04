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
import Swooft

func equal<T: Equatable>(_ expected: LinkedList<T>) -> Predicate<LinkedList<T>> {
    return Predicate.simple("equal \(expected)") { expression in
        guard let actual = try expression.evaluate() else {
            return .doesNotMatch
        }
        return PredicateStatus(bool: expected == actual)
    }
}

func == <T: Equatable>(lhs: Expectation<LinkedList<T>>, rhs: LinkedList<T>) {
    lhs.to(equal(rhs))
}

func != <T: Equatable>(lhs: Expectation<LinkedList<T>>, rhs: LinkedList<T>) {
    lhs.toNot(equal(rhs))
}

class LinkedListTests: QuickSpec {

    override func spec() {

        describe("count") {

            it("should be correct") {
                var list: LinkedList<Int> = [1, 2, 5, 8]
                expect(list.count) == 4
                let node = list.append(3)
                expect(list.count) == 5
                list.prepend(LinkedListNode(7))
                expect(list.count) == 6
                list.remove(node)
                expect(list.count) == 5
                list.removeFront()
                expect(list.count) == 4
                list.removeBack()
                expect(list.count) == 3
                expect(list) == [1, 2, 5]
            }
        }

        describe("empty list") {

            it("should equal other empty list") {
                let list: LinkedList<Int> = []
                expect(list) == []
            }

            it("should have count 0") {
                let list: LinkedList<Int> = []
                expect(list.count) == 0
            }
        }

        describe("append") {

            it("should add to end") {
                var list = LinkedList<Int>()
                list.append(1)
                list.append(9)
                expect(list) == [1, 9]
            }
        }

        describe("prepend") {

            it("should add to beginning") {
                var list = LinkedList<Int>()
                list.prepend(1)
                list.prepend(9)
                expect(list) == [9, 1]
            }
        }

        describe("removeFront") {

            it("should remove from front") {
                var list: LinkedList<Int> = [1, 2, 5, 8]
                let front = list.removeFront()
                expect(front?.value) == 8
                expect(list) == [1, 2, 5]
            }
        }

        describe("removeBack") {

            it("should remove from back") {
                var list: LinkedList<Int> = [7, 2, 5, 8]
                let back = list.removeBack()
                expect(back?.value) == 7
                expect(list) == [2, 5, 8]
            }
        }

        describe("equality") {

            it("return true on equal") {
                let a: LinkedList<Int> = [1, 2, 5, 8]
                let b: LinkedList<Int> = [1, 2, 5, 8]
                expect(a) == b
            }

            it("return false on unequal") {
                let a: LinkedList<Int> = [1, 2, 5, 8]
                let b: LinkedList<Int> = [1, 2, 3, 8]
                expect(a) != b
            }
        }

        describe("subscript") {

            it("should get element") {
                let list: LinkedList<Int> = [1, 4, 8]
                expect(list[0]) == 1
                expect(list[1]) == 4
                expect(list[2]) == 8
            }

            it("should be nil if passed end") {
                let list: LinkedList<Int> = [1, 4, 8]
                expect(list[list.count]).to(beNil())
            }
        }
    }
}
