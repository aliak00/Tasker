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

    let configuration: TaskInterceptorConfiguration

    init(configuration: TaskInterceptorConfiguration = .default) {
        self.configuration = configuration
    }

    var interceptCallCount = 0
    var interceptCallData: [(weakAnyTask: WeakAnyTask, currentBatchCount: Int)] = []
    var interceptCallResultData: [InterceptCommand] = []
    var interceptBlock: (AnyTask<Any>, Int) -> InterceptCommand = { _,_  in .execute }

    var executeCallCount = 0
    var executeCallData: [(Error?) -> Void] = []
    var executeBlock: (@escaping (Error?) -> Void) -> Void = { _ in }

    var shouldExecuteCallCount = 0
    var shouldExecuteCallData: [(anyResult: AnyResult, anyTask: WeakAnyTask, handle: TaskHandle)] = []
    var shouldExecuteBlock: (AnyResult, AnyTask<Any>, TaskHandle) -> Bool = { _,_,_  in true }

    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand {
        defer { self.interceptCallCount += 1 }
        self.interceptCallData.append((WeakAnyTask(task: task), currentBatchCount))
        return self.interceptBlock(AnyTask(task: task), currentBatchCount)
    }

    func execute(done: @escaping (Error?) -> Void) {
        self.executeCallData.append(done)
        self.executeBlock(done)
        self.executeCallCount += 1
    }

    func shouldExecute<T>(after result: Result<T.SuccessValue>, from task: T, with handle: TaskHandle) -> Bool where T: Task {
        defer { self.shouldExecuteCallCount += 1 }
        let anyResult = AnyResult(result)
        let anyTask = AnyTask<Any>(task: task)
        self.shouldExecuteCallData.append((anyResult, WeakAnyTask(task: task), handle))
        return self.shouldExecuteBlock(anyResult, anyTask, handle)
    }
}
