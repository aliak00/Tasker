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

public struct TaskReactorConfiguration {
    let isImmediate: Bool
    let timeout: DispatchTimeInterval?
    let requeuesTask: Bool
    let suspendsTaskQueue: Bool

    public init(
        isImmediate: Bool = false,
        timeout: DispatchTimeInterval? = nil,
        requeuesTask: Bool = false,
        suspendsTaskQueue: Bool = false
    ) {
        self.isImmediate = isImmediate
        self.timeout = timeout
        self.requeuesTask = requeuesTask
        self.suspendsTaskQueue = suspendsTaskQueue
    }

    public static let `default` = TaskReactorConfiguration()
}
