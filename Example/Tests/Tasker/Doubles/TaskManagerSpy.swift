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
import Nimble
import Quick
@testable import Swooft

class TaskManagerSpy {

    let taskManager: TaskManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: [AnyResult] = []

    init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = []) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
    }

    @discardableResult
    func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        completion: (@escaping (T.Result) -> Void) = { _ in }
    ) -> TaskHandle {
        return self.taskManager.add(task: task, startImmediately: startImmediately, after: interval) { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            defer {
                strongSelf.completionCallData.append(AnyResult(result))
            }
            completion(result)
        }
    }
}
