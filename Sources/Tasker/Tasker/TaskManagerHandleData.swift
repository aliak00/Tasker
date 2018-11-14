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
        let taskReference: AnyObject
        let completionErrorCallback: (TaskError) -> Void
        let taskDidCancelCallback: (TaskError) -> Void
        let intercept: (DispatchTimeInterval?, @escaping (TaskInterceptorManager.InterceptResult) -> Void) -> Void
        let completionQueue: DispatchQueue?

        init(
            operation: AsyncOperation,
            taskReference: AnyObject,
            completionErrorCallback: @escaping (TaskError) -> Void,
            taskDidCancelCallback: @escaping (TaskError) -> Void,
            intercept: @escaping (DispatchTimeInterval?, @escaping (TaskInterceptorManager.InterceptResult) -> Void) -> Void,
            completionQueue: DispatchQueue?
        ) {
            self.operation = operation
            self.taskReference = taskReference
            self.completionErrorCallback = completionErrorCallback
            self.taskDidCancelCallback = taskDidCancelCallback
            self.intercept = intercept
            self.completionQueue = completionQueue
        }
    }
}
