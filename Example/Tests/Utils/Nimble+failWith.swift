//
//  Nimble+failWith.swift
//  Swooft_Tests
//
//  Created by Ali Akhtarzada on 11/21/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
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
