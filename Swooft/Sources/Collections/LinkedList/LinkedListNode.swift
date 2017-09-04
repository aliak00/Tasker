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

public class LinkedListNode<Element> {
    public let value: Element

    public init(_ value: Element) {
        self.value = value
    }

    var next: LinkedListNode<Element>?
    weak var previous: LinkedListNode<Element>?
}

///
/// Returns true if the rhs and lhs have the same value, and same previous and next values
///
public func == <Element: Equatable>(lhs: LinkedListNode<Element>, rhs: LinkedListNode<Element>) -> Bool {
    return lhs.value == rhs.value && lhs.next?.value == rhs.next?.value && lhs.previous?.value == rhs.previous?.value
}

extension LinkedListNode: CustomStringConvertible {
    public var description: String {
        var pString = "nil"
        if let previous = self.previous {
            pString = "\(Unmanaged.passUnretained(previous).toOpaque())"
        }
        var nString = "nil"
        if let next = self.next {
            nString = "\(Unmanaged.passUnretained(next).toOpaque())"
        }
        return "[value: \(self.value), previous: \(pString), next: \(nString)]"
    }
}
