//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Quick
import Nimble
@testable import Swooft

// This interceptor will take any task that is retriable, and re-execute it
class BatchingInterceptor: TaskInterceptor {
    func intercept<T: Task>(task _: inout T, currentBatchCount: Int) -> InterceptCommand {
        return currentBatchCount < 9 ? .hold : .execute
    }
}

class ScenarioBatchingTests: QuickSpec {

    override func spec() {

        it("should all work") {
            let manager = TaskManagerSpy(interceptors: [BatchingInterceptor()])
            for i in 0..<9 {
                manager.add(task: TaskSpy { $0(.success(i)) })
            }
            ensure(manager.completionCallCount).stays(0)
            manager.add(task: TaskSpy { $0(.success(())) })
            ensure(manager.completionCallCount).becomes(10)
        }
    }
}
