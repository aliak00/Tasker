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
import Tasker

private extension TaskManagerSpy {
    @discardableResult
    func launch<T: Task>(task: @autoclosure () -> T, count: Int) -> (handles: [TaskHandle], tasks: [T]) {
        var handles: [TaskHandle] = []
        var tasks: [T] = []
        for _ in 0..<count {
            let task = task()
            handles.append(self.add(task: task))
            tasks.append(task)
        }
        return (handles, tasks)
    }
}

class TaskManagerTests: XCTestCase {

    override func tearDown() {
        ensure(kTaskSpyCounter.value).becomes(0)
    }

    func testAddingATaskShouldExecuteIt() {
        let manager = TaskManagerSpy()
        let task = TaskSpy { $0(.success(())) }
        manager.add(task: task)
        ensure(task.executeCallCount).becomes(1)
    }

    func testAddingATaskShouldCallCompletionCallback() {
        let manager = TaskManagerSpy()
        manager.add(task: kDummyTask)
        ensure(manager.completionCallCount).becomes(1)
    }

    func testAddingATaskShouldNotExecuteIfNotToldTo() {
        let manager = TaskManagerSpy()
        let handle = manager.add(task: kDummyTask, startImmediately: false)
        ensure(handle.state).stays(.pending)
    }

    func testAddingATaskShouldCallCompletionCallbackAfterGivenInterval() {
        let manager = TaskManagerSpy()
        let interval: DispatchTimeInterval = .milliseconds(20)
        let shouldStartAfter: DispatchTime = .now() + interval
        var didStartAfter: DispatchTime!
        let task = TaskSpy<Void> { cb in
            didStartAfter = .now()
            cb(.success(()))
        }

        manager.add(task: task, after: interval)
        ensure(manager.completionCallCount).becomes(1)
        XCTAssertGreaterThan(didStartAfter, shouldStartAfter)
    }

    func testAddingManyTasksShouldCallAllCallbacks() {
        let manager = TaskManagerSpy()
        manager.launch(task: TaskSpy { $0(.success(())) }, count: 100)
        ensure(manager.completionCallCount).becomes(100)
    }

    func testAddingManyTasksShouldExecuteAllTasks() {
        let manager = TaskManagerSpy()
        let (_, tasks) = manager.launch(task: TaskSpy { $0(.success(())) }, count: 100)
        for task in tasks {
            ensure(task.executeCallCount).becomes(1)
        }
        ensure(manager.completionCallCount).becomes(100)
    }

    func testAddingManyTasksShouldMakeAllHandlesFinished() {
        let manager = TaskManagerSpy()
        let (handles, _) = manager.launch(task: TaskSpy { $0(.success(())) }, count: 100)
        for handle in handles {
            ensure(handle.state).becomes(TaskState.finished)
        }
    }
}
