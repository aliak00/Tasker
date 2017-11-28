//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Nimble
import Quick
@testable import Swooft

class TaskInterceptorTests: QuickSpec {
    override func spec() {

        describe("intercept") {

            it("should be called with task") {
                let interceptor = InterceptorSpy()
                let manager = TaskManagerSpy(interceptors: [interceptor])
                let task = TaskSpy { $0(.success(())) }
                manager.add(task: task)
                ensure(interceptor.interceptCallCount).becomes(1)
                expect(interceptor.interceptCallData[0].anyTask) === task
            }

            it("should modify original task") {
                let interceptor = InterceptorSpy()
                interceptor.interceptBlock = { anyTask, _ in
                    let task = anyTask as! TaskSpy<Void>
                    task.executeCallBackData.append(AnyResult(Result<Int>.success(1)))
                    return .execute
                }
                let manager = TaskManagerSpy(interceptors: [interceptor])
                let task = TaskSpy { $0(.success(())) }
                manager.add(task: task)
                ensure(interceptor.interceptCallCount).becomes(1)
                ensure(task.executeCallCount).becomes(2)
            }
        }
    }
}
