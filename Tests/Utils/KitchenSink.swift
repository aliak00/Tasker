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
