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

class ReactorSpy: TaskReactor {

    let configuration: TaskReactorConfiguration

    init(configuration: TaskReactorConfiguration = .default) {
        self.configuration = configuration
    }

    var executeCallCount: Int {
        return self.executeCallData.count
    }

    var executeCallData: [(Error?) -> Void] = []
    var executeBlock: (@escaping (Error?) -> Void) -> Void = { _ in }

    var shouldExecuteCallCount: Int {
        return self.shouldExecuteCallData.count
    }
    var shouldExecuteCallData: [(anyResult: AnyResult, weakAnyTask: Weak<AnyTask<Any>>, handle: TaskHandle)] = []
    var shouldExecuteBlock: (AnyResult, AnyTask<Any>, TaskHandle) -> Bool = { _, _, _ in true }

    func execute(done: @escaping (Error?) -> Void) {
        defer {
            self.executeCallData.append(done)
        }
        self.executeBlock(done)
    }

    func shouldExecute<T>(after result: Result<T.SuccessValue>, from task: T, with handle: TaskHandle) -> Bool where T: Task {
        let anyResult = AnyResult(result)
        let anyTask = AnyTask<Any>(task)
        defer {
            self.shouldExecuteCallData.append((anyResult, Weak(anyTask), handle))
        }
        return self.shouldExecuteBlock(anyResult, anyTask, handle)
    }
}
