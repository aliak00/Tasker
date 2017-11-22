//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

public class EventEmitterHandle<Parameters>: Hashable {

    public typealias DelegateType = Delegate<Parameters, Void>

    let delegate: DelegateType
    var descriptionText: String

    init<T: AnyObject>(object: T, method: @escaping (T) -> DelegateType.Capture) {
        self.delegate = DelegateType(object: object, method: method)
        self.descriptionText = "\(T.self)"
    }

    init(closure: @escaping DelegateType.Capture) {
        self.delegate = Delegate(closure: closure)
        self.descriptionText = "block"
    }

    public var hashValue: Int {
        return Unmanaged.passUnretained(self).toOpaque().hashValue
    }
}

public func == <P>(lhs: EventEmitterHandle<P>, rhs: EventEmitterHandle<P>) -> Bool {
    return lhs === rhs
}
