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

class TaskHandleTests: QuickSpec {
    override func spec() {

        describe("cancel") {

            it("should cancel a task") {
                let manager = TaskManagerSpy()
                let handle = manager.add(task: kDummyTask)
                handle.cancel()
                expect(handle.state) == TaskState.finished
                ensure(manager.completionCallCount).becomes(1)
                expect(manager.completionCallData[0]).to(failWith(TaskError.cancelled))
            }
        }

        describe("start") {

            it("should start a task") {
                let manager = TaskManagerSpy()
                let handle = manager.add(task: kDummyTask, startImmediately: false)
                ensure(handle.state).stays(.pending)
                handle.start()
                ensure(handle.state).becomes(.finished)
            }
        }
    }
}
