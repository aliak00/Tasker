//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Swooft

class InterceptorSpy: TaskInterceptor {

    var interceptCallCount: Int {
        return self.interceptCallData.count
    }

    var interceptCallData: [(anyTask: AnyTask<Any>, currentBatchCount: Int)] = []
    var interceptCallResultData: [InterceptCommand] = []
    var interceptBlock: (AnyTask<Any>, Int) -> InterceptCommand = { _, _ in .execute }

    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand {
        let anyTask = AnyTask<Any>(task)
        let result = self.interceptBlock(anyTask, currentBatchCount)
        defer {
            self.interceptCallData.append((anyTask, currentBatchCount))
            self.interceptCallResultData.append(result)
        }
        return result
    }
}
