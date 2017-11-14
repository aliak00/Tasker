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

extension Task {
    @discardableResult
    public func async(
        with taskManager: TaskManager? = nil,
        after interval: DispatchTimeInterval? = nil,
        queue _: DispatchQueue? = nil,
        timeout: DispatchTimeInterval? = nil,
        completion: ResultCallback? = nil
    ) -> TaskHandle {
        return (taskManager ?? TaskManager.shared).add(
            task: self,
            after: interval,
            timeout: timeout,
            completion: completion
        )
    }
}
