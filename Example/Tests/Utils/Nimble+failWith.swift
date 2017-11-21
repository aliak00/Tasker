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

import Nimble
import Swooft

func failWith<T>(_ expectedError: Error) -> Predicate<Result<T>> {
    let domain = (expectedError as NSError).domain
    return Predicate.simple("get <failure(\(domain).\(expectedError))>") { expression in
        guard let result = try expression.evaluate(), case let .failure(actualError) = result else {
            return .doesNotMatch
        }
        let a = actualError as NSError
        let b = expectedError as NSError
        return PredicateStatus(bool: a.code == b.code && a.domain == b.domain)
    }
}
