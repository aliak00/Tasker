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

extension TaskManager.Handle {
    class Data {
        var operation: AsyncOperation
        let anyTask: AnyTask<Any>
        let completionErrorCallback: (TaskError) -> Void
        let intercept: (DispatchTimeInterval?, @escaping (TaskManager.InterceptorManager.InterceptResult) -> Void) -> Void
        let completionQueue: DispatchQueue?

        init(
            operation: AsyncOperation,
            anyTask: AnyTask<Any>,
            completionErrorCallback: @escaping (TaskError) -> Void,
            intercept: @escaping (DispatchTimeInterval?, @escaping (TaskManager.InterceptorManager.InterceptResult) -> Void) -> Void,
            completionQueue: DispatchQueue?
        ) {
            self.operation = operation
            self.anyTask = anyTask
            self.completionErrorCallback = completionErrorCallback
            self.intercept = intercept
            self.completionQueue = completionQueue
        }
    }
}
