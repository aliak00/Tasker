//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import XCTest
@testable import Tasker

class TaskInterceptorTests: XCTestCase {
    override func tearDown() {
        ensure(kTaskSpyCounter.value).becomes(0)
    }

    func testInterceptShouldBeCalledWithTask() {
        let interceptor = InterceptorSpy()
        let manager = TaskManagerSpy(interceptors: [interceptor])
        let task = TaskSpy { $0(.success(())) }
        manager.add(task: task)
        ensure(interceptor.interceptCallCount).becomes(1)
        XCTAssertTrue(interceptor.interceptCallData[0].anyTask === task)
    }

    func testInterceptShouldModifyOriginalTask() {
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
