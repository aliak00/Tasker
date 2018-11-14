//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Tasker

class InterceptorSpy: TaskInterceptor {

    var interceptCallCount: Int {
        return self.interceptCallData.count
    }

    var interceptCallData: [(anyTask: AnyObject, currentBatchCount: Int)] = []
    var interceptCallResultData: [InterceptCommand] = []
    var interceptBlock: (AnyObject, Int) -> InterceptCommand = { _, _ in .execute }

    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand {
        let result = self.interceptBlock(task, currentBatchCount)
        defer {
            self.interceptCallData.append((task, currentBatchCount))
            self.interceptCallResultData.append(result)
        }
        return result
    }
}
