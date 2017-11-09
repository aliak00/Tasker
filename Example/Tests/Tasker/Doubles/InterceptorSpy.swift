/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

@testable import Swooft

//
// This is needed because InterceptorSpy stores tasks that are passed to it
// and TaskSpy stores the interceptors that are passed to it so you get a
// retain cycle
//
class WeakAnyTask {
    weak var anyTask: AnyObject?
    init<T: Task>(task: T) {
        self.anyTask = task
    }
}

class InterceptorSpy: TaskInterceptor {

    var interceptCallCount = 0
    var interceptCallData: [(weakAnyTask: WeakAnyTask, currentBatchCount: Int)] = []
    var interceptCallResultData: [InterceptCommand] = []
    var interceptBlock: (AnyTask<Any>, Int) -> InterceptCommand = { _,_  in .execute }

    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand {
        defer { self.interceptCallCount += 1 }
        self.interceptCallData.append((WeakAnyTask(task: task), currentBatchCount))
        return self.interceptBlock(AnyTask(task: task), currentBatchCount)
    }
}
