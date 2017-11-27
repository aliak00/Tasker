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

public enum JSONError: Error {
    case noKey(String)
    case parse(Error)
    case notDictionary(Any)
    case notString(String)
    case notJSONObject(String)
    case notNumber(String)
    case notBoolean(String)
    case notArrayOf(String, forKey: String)
}

extension JSONError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .noKey(key):
            return "Did not find key \(key)"
        case let .parse(error):
            return "JSON error: \(error)"
        case let .notDictionary(object):
            return "Expected json dictionary but got \(object)"
        case let .notString(key):
            return "Key \(key) was not convertible to string"
        case let .notJSONObject(key):
            return "Key \(key) was not convertible to JSON object"
        case let .notNumber(key):
            return "Key \(key) was not convertible to number"
        case let .notBoolean(key):
            return "Key \(key) was not convertible to boolean"
        case let .notArrayOf(type, key):
            return "Key \(key) was not convertible to Array<\(type)>"
        }
    }
}
