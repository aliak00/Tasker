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

/**
 A task reactor allows you to control what the task manager should after a task is completed
 */
public protocol TaskReactor {
    /**
     Return true if you want this interceptor to be executed

     - parameter after: the result of the task that was just executed
     - parameter from: the actual task that was just executed
     - parameter with: the handle to the task that was just executed
     */
    func shouldExecute<T: Task>(after: T.TaskResult, from: T, with: TaskHandle) -> Bool

    /**
     Does the interceptor work
     */
    func execute(done: @escaping (Error?) -> Void)

    /**
     The configuration that this interceptor has
     */
    var configuration: TaskReactorConfiguration { get }
}

extension TaskReactor {
    func execute(done: @escaping (Error?) -> Void) {
        done(nil)
    }

    func shouldExecute<T: Task>(after _: T.TaskResult, from _: T, with _: TaskHandle) -> Bool {
        return false
    }

    var configuration: TaskReactorConfiguration {
        return .default
    }
}
