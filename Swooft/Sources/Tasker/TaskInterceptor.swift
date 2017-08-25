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

import Foundation

public enum InterceptCommand {
    case execute
    case hold
    case ignore
    case forceExecute
}

public protocol TaskInterceptor {
    func intercept<T: Task>(task: T, currentBatchCount: Int) -> InterceptCommand

    func shouldExecute<T: Task>(after: T.TaskResult, from: T, with: TaskHandle) -> Bool
    func execute(done: @escaping (Error?) -> Void)

    var configuration: TaskInterceptorConfiguration { get }
}

public extension TaskInterceptor {
    func intercept<T: Task>(task _: T, currentBatchCount _: Int) -> InterceptCommand {
        return .execute
    }

    func execute(done: @escaping (Error?) -> Void) {
        done(nil)
    }

    func shouldExecute<T: Task>(after _: T.TaskResult, from _: T, with _: TaskHandle) -> Bool {
        return false
    }

    var configuration: TaskInterceptorConfiguration {
        return .default
    }
}
