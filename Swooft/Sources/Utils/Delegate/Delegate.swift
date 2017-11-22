//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

public enum Delegate<Parameters, Return> {

    public typealias Capture = (Parameters) -> Return

    case closure(Capture)
    case method(weakObject: Weak<AnyObject>, method: (AnyObject) -> Capture)

    public func call(_ args: Parameters) -> Return? {
        switch self {
        case let .method(weakObject, method):
            guard let object = weakObject.value else {
                return nil
            }
            return method(object)(args)
        case let .closure(closure):
            return closure(args)
        }
    }

    public init<T: AnyObject>(object: T?, method: @escaping (T) -> Capture) {
        let typeErasedMethod: (AnyObject) -> Capture = { any in
            method(any as! T) // swiftlint:disable:this force_cast
        }
        self = .method(weakObject: Weak(object), method: typeErasedMethod)
    }

    public init(closure: @escaping Capture) {
        self = .closure(closure)
    }

    public var isValid: Bool {
        switch self {
        case .closure:
            return true
        case let .method(weakObject, _):
            return weakObject.value != nil
        }
    }

    public func capture() -> Capture? {
        switch self {
        case let .closure(closure):
            return closure
        case let .method(weakObject, method):
            guard let object = weakObject.value else {
                return nil
            }
            return method(object)
        }
    }
}
