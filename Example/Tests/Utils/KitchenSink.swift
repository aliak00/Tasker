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
import Quick
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

func sleep(for interval: DispatchTimeInterval) {
    switch interval {
    case let .microseconds(value):
        usleep(useconds_t(value))
    case let .milliseconds(value):
        usleep(useconds_t(1000 * value))
    case let .nanoseconds(value):
        var requiredTimespec = timespec(tv_sec: 0, tv_nsec: value)
        withUnsafePointer(to: &requiredTimespec) { ptr in
            let actualTimespecPointer = UnsafeMutablePointer<timespec>.init(bitPattern: 0)
            nanosleep(ptr, actualTimespecPointer)
        }
    case let .seconds(value):
        usleep(useconds_t(1000 * 1000 * value))
    case .never:
        break
    }
}
