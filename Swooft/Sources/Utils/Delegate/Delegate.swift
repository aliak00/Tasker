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

    public typealias Closure = (Parameters) -> Return

    case closure(Closure)
    case method(weakObject: Weak<AnyObject>, method: (AnyObject) -> Closure)

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

    public init<T: AnyObject>(object: T?, method: @escaping (T) -> Closure) {
        let typeErasedMethod: (AnyObject) -> Closure = { any in
            method(any as! T) // swiftlint:disable:this force_cast
        }
        self = .method(weakObject: Weak(object), method: typeErasedMethod)
    }

    public init(closure: @escaping Closure) {
        self = .closure(closure)
    }

    public func capture() -> Closure? {
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
