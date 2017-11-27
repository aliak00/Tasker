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

extension Data {
    public func jsonObject() throws -> JSONObject {
        let json: Any
        do {
            json = try JSONSerialization.jsonObject(with: self, options: JSONSerialization.ReadingOptions())
        } catch {
            throw JSONError.parse(error)
        }
        guard let unwrappedJson = json as? JSONObject else {
            throw JSONError.notDictionary(json)
        }
        return unwrappedJson
    }
}
