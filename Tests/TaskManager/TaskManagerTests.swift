@testable import Tasker
import XCTest

private extension TaskManagerSpy {
    @discardableResult
    func launch<T: Task>(
        task: @autoclosure () -> T,
        count: Int,
        startImmediately: Bool = true,
        completion: T.CompletionCallback? = nil
    ) -> (handles: [Handle], tasks: [T]) {
        var handles: [Handle] = []
        var tasks: [T] = []
        for _ in 0 ..< count {
            let task = task()
            handles.append(self.add(task: task, startImmediately: startImmediately, completion: completion))
            tasks.append(task)
        }
        return (handles, tasks)
    }
}

class TaskManagerTests: XCTestCase {
    override func setUp() {
        self.addTeardownBlock {
            ensure(kTaskSpyCounter.value).becomes(0)
        }
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
        let didStartAfter = Atomic<DispatchTime>(.distantFuture)
        let task = TaskSpy<Void> { cb in
            didStartAfter.value = .now()
            cb(.success(()))
        }

        manager.add(task: task, after: interval)
        ensure(manager.completionCallCount).becomes(1)
        XCTAssertGreaterThan(didStartAfter.value, shouldStartAfter)
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

    func testWaitingForAllTasksToFinish() {
        let manager = TaskManagerSpy()
        let count = AtomicInt(0)
        manager.launch(task: TaskSpy<Void> { cb in
            count.getAndIncrement()
            cb(.success(()))
        }, count: 100)
        manager.waitTillAllTasksFinished()
        XCTAssertEqual(count.value, 100)
    }

    func testCompletionCallbackCalled() {
        let manager = TaskManagerSpy()
        let count = AtomicInt()
        manager.launch(task: kDummyTask, count: 100) { _ in
            count.getAndIncrement()
        }
        ensure(manager.completionCallCount).becomes(100)
        XCTAssertEqual(count, 100)
    }

    func testChangingCompletionHandlerCalled() {
        let manager = TaskManagerSpy()
        let count = AtomicInt()
        let (handles, _) = manager.launch(task: kDummyTask, count: 100, startImmediately: false) { _ in
            count.getAndIncrement()
        }
        for handle in handles {
            manager.setCompletion(task: kDummyTask, handle: handle) { _ in
                count.getAndDecrement()
            }
            handle.start()
        }
        ensure(manager.completionCallCount).becomes(100)
        XCTAssertEqual(count, -100)
    }
}
