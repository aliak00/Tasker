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

struct NoError: Error {}
let noError = NoError()

public enum Result<T> {

    case success(T)
    case failure(Error)

    var successValue: T? {
        if case let .success(value) = self {
            return value
        }
        return nil
    }

    var failureValue: Error? {
        if case let .failure(error) = self {
            return error
        }
        return nil
    }

    func materialize() throws -> T {
        switch self {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}
