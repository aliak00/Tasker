@testable import Tasker
import XCTest

class ReactorTests: XCTestCase {
    override func tearDown() {
        ensure(kTaskSpyCounter.value).becomes(0)
    }

    func testTaskManagerShouldCancelReactorOnTimeout() {
        let reactor = ReactorSpy(configuration: ReactorConfiguration(timeout: .milliseconds(5), requeuesTask: true))
        reactor.executeBlock = { sleep(for: .milliseconds(10)); $0(nil) }
        let manager = TaskManagerSpy(reactors: [reactor])
        manager.add(task: TaskSpy { $0(.success(())) })
        ensure(manager.completionCallCount).becomes(1)
        XCTAssertErrorEqual(manager.completionCallData.data.first?.failureValue, TaskError.reactorTimedOut(type: ReactorSpy.self))
    }

    func testTaskManagerShouldCompleteReactorIfUnderTimeout() {
        let reactor = ReactorSpy(configuration: ReactorConfiguration(timeout: .milliseconds(10)))
        reactor.executeBlock = { sleep(for: .milliseconds(5)); $0(nil) }
        let manager = TaskManagerSpy(reactors: [reactor])
        manager.add(task: TaskSpy { $0(.success(())) })
        ensure(manager.completionCallCount).becomes(1)
        XCTAssertNil(manager.completionCallData.data.first?.failureValue)
    }

    func testTaskManagerShouldReExecuteTasksIfReactorSaysRequeue() {
        let reactor = ReactorSpy(configuration: ReactorConfiguration(requeuesTask: true))
        reactor.executeBlock = { done in
            sleep(for: .milliseconds(1))
            done(nil)
        }
        reactor.shouldExecuteBlock = { anyResult, anyTask, _ in
            // Only on first task execution block
            guard (anyTask as! TaskSpy<Int>).executeCallCount == 1 else {
                return false
            }
            // And only if even
            return (anyResult.successValue! as! Int) % 2 == 0
        }

        let manager = TaskManagerSpy(reactors: [reactor])

        // Run tasks that ask to be reacted to, and then not
        let numTasks = 10
        var tasks: [TaskSpy<Int>] = []
        for i in (0..<numTasks).yielded(by: .milliseconds(1)) {
            let task = TaskSpy { $0(.success(i)) }
            tasks.append(task)
            manager.add(task: task)
        }

        ensure(manager.completionCallCount).becomes(numTasks)

        for (index, task) in tasks.enumerated() {
            if index % 2 == 0 {
                XCTAssertEqual(task.executeCallCount, 2)
            } else {
                XCTAssertEqual(task.executeCallCount, 1)
            }
        }
    }

    func testTaskManagerShouldNotStartCompleteTasksTillAfterReactorIsCompleted() {
        let reactor = ReactorSpy(configuration: ReactorConfiguration(requeuesTask: true, suspendsTaskQueue: false))

        // If reactor returns without calling the done callback, then TaskManager
        // will just assume it's still running.
        reactor.executeBlock = { _ in } // do nothing, never call done

        // Only execute reactor on a task once
        reactor.shouldExecuteBlock = { _, anyTask, _ in (anyTask as! TaskSpy<Void>).executeCallCount == 1 }

        // Trigger a task execution pipeline and therefore a reactor execution
        let manager = TaskManagerSpy(reactors: [reactor])
        manager.add(task: TaskSpy { $0(.success(())) })

        ensure(reactor.executeCallCount).becomes(1)

        // Add in a bunch more tasks
        var handles: [(Handle, TaskSpy<Void>)] = []
        for _ in 0..<10 {
            let task = TaskSpy { $0(.success(())) }
            handles.append((manager.add(task: task), task))
        }

        // The execution count should stay 1
        ensure(reactor.executeCallCount).stays(1)

        for (handle, task) in handles {
            ensure(task.executeCallCount).becomes(1)
            ensure(handle.state).becomes(.executing)
        }

        ensure(manager.completionCallCount).stays(0)

        // Call the done callback of the first reactor execute call
        reactor.executeCallData.data.first?(nil)

        // All tasks should complete
        ensure(manager.completionCallCount).becomes(handles.count + 1)

        for (handle, task) in handles {
            ensure(handle.state).becomes(TaskState.finished)
            XCTAssertEqual(task.executeCallCount, 2)
        }
    }
}
