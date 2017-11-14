//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

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
