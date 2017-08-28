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

func equal<T: Equatable>(_ expected: RingBuffer<T>) -> Predicate<RingBuffer<T>> {
    return Predicate.simple("equal \(expected)") { expression in
        guard let actual = try expression.evaluate() else {
            return .doesNotMatch
        }
        return PredicateStatus(bool: expected == actual)
    }
}

public func ==<T: Equatable>(lhs: Expectation<RingBuffer<T>>, rhs: RingBuffer<T>) {
    lhs.to(equal(rhs))
}

class RingBufferTests: QuickSpec {

    override func spec() {

        describe("ring buffer") {

            it("should wrap appends") {
                var r1: RingBuffer<Int> = [1, 2, 3]
                r1.append(4)
                let r2: RingBuffer<Int> = [4, 2, 3]
                expect(r1) == r2
            }

            it("should provide accurate count") {
                var r1 = RingBuffer<Int>(capacity: 10)
                expect(r1.capacity) == 10
                r1.append(0)
                r1.append(0)
                expect(r1.count) == 2
                let r2: RingBuffer<Int> = [0, 0]
                expect(r1) == r2
            }

            it("should equal another similar") {
                let r1: RingBuffer<Int> = [0, 1, 2]
                let r2: RingBuffer<Int> = [0, 1, 2]
                expect(r1) == r2
            }
        }
    }
}
