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

/**
 A generic wrapper that can be used on a reference type and store it inside
 as a weak reference

 ## Motivation

 A weak wrapper comes in useful in a number of situations:
    * When you want a protocol to ensure the existence of a weak reference. While you can declare a var
      weak in the protocol, there's no way to enforce it in an implementing class.
    * If you want the values in a container to contain weak references so that they can be deallocated
      regardless of being inserted in to a container
 */
public struct Weak<T: AnyObject> {
    /**
     The value of the object this was initialized with
     */
    public weak var value: T?

    /**
     - parameter value: the value to store weakly
     */
    public init(_ value: T?) {
        self.value = value
    }
}
