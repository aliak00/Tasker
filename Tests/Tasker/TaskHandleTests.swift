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

class TaskHandleTests: XCTestCase {

    override func setUp() {
        TaskManager.Handle.counter.value = 0
    }

    override func tearDown() {
        ensure(AsyncOperation.counter.value).becomes(0)
        AsyncOperation.counter.value = 0
    }

    func testCancelShouldCancelATask() {
        let manager = TaskManagerSpy()
        let handle = manager.add(task: kDummyTask)
        handle.cancel()
        XCTAssertEqual(handle.state, TaskState.finished)
        ensure(manager.completionCallCount).becomes(1)
        XCTAssertEqual(TaskError.cancelled as NSError, manager.completionCallData[0].failureValue! as NSError)
    }

    func testStartShouldStartATask() {
        let manager = TaskManagerSpy()
        let handle = manager.add(task: kDummyTask, startImmediately: false)
        ensure(handle.state).stays(.pending)
        handle.start()
        ensure(handle.state).becomes(.finished)
    }
}
