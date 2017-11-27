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
@testable import Swooft

class TaskerConfiguration: QuickConfiguration {
    override class func configure(_ configuration: Configuration) {
        configuration.beforeEach {
            TaskManager.Handle.counter.value = 0
        }

        configuration.afterEach {
            ensure(AsyncOperation.counter.value).becomes(0, timeout: .seconds(3))
            AsyncOperation.counter.value = 0
        }
    }
}
