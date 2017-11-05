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
 A command that can be returned by a `TaskInterceptor` intercept call that tells a `TaskManager` what it should
 do with a task
 */
public enum InterceptCommand {
    /**
     Proceed with execution of the task

     - Note: This will cause all held tasks to be executed as well
     */
    case execute

    /// Hold on to this task for now
    case hold

    /// Discard this task (throws it away)
    case discard

    /**
     Ignored hold and execute commands and executes the task

     - Note: This will cause all held tasks to be executed as well
     */
    case forceExecute
}

/**
 A task interceptor allows you to somewhat control what the task manager should do when it encounters a task
 */
public protocol TaskInterceptor {
    /**
     This is called on every task and allows you to tell the task manager how to treat
     this task based on the `InterceptCommand` that you return
     */
    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand
}

