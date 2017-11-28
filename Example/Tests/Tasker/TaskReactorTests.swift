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

class TaskReactorTests: QuickSpec {
    override func spec() {

        describe("task manager") {

            it("should cancel reactor on timeout") {
                let reactor = ReactorSpy(configuration: TaskReactorConfiguration(timeout: .milliseconds(5), requeuesTask: true))
                reactor.executeBlock = { sleep(for: .milliseconds(10)); $0(nil) }
                let manager = TaskManagerSpy(reactors: [reactor])
                manager.add(task: TaskSpy { $0(.success(())) })
                ensure(manager.completionCallCount).becomes(1)
                expect(manager.completionCallData[0]).to(failWith(TaskError.reactorTimedOut(type: ReactorSpy.self)))
            }

            it("should complete reactor if under timeout") {
                let reactor = ReactorSpy(configuration: TaskReactorConfiguration(timeout: .milliseconds(10)))
                reactor.executeBlock = { sleep(for: .milliseconds(5)); $0(nil) }
                let manager = TaskManagerSpy(reactors: [reactor])
                manager.add(task: TaskSpy { $0(.success(())) })
                ensure(manager.completionCallCount).becomes(1)
                expect(manager.completionCallData[0]).toNot(failWith(TaskError.reactorTimedOut(type: ReactorSpy.self)))
            }

            it("should re-execute tasks if reactor says requeue") {
                let reactor = ReactorSpy(configuration: TaskReactorConfiguration(requeuesTask: true))
                reactor.executeBlock = { done in
                    sleep(for: .milliseconds(1))
                    done(nil)
                }
                reactor.shouldExecuteBlock = { anyResult, anyTask, _ in
                    guard (anyTask as! TaskSpy<Int>).executeCallBackData.count == 1 else {
                        return false
                    }
                    return (anyResult.successValue! as! Int) % 2 == 0
                }

                let manager = TaskManagerSpy(reactors: [reactor])

                // Run tasks that ask to be reacted to, and then not
                let numTasks = 4
                var tasks: [TaskSpy<Int>] = []
                for i in (0..<numTasks).yielded(by: .milliseconds(1)) {
                    let task = TaskSpy { $0(.success(i)) }
                    tasks.append(task)
                    manager.add(task: task)
                }

                ensure(manager.completionCallCount).becomes(numTasks)

                for (index, task) in tasks.enumerated() {
                    if index % 2 == 0 {
                        expect(task.executeCallCount) == 2
                    } else {
                        expect(task.executeCallCount) == 1
                    }
                }
            }

            it("should not start complete tasks till after reactor is completed") {
                let reactor = ReactorSpy(configuration: TaskReactorConfiguration(requeuesTask: true, suspendsTaskQueue: true))

                // First let it hang, it should pause the queue then we can call the callback later to finish the interceptor
                reactor.executeBlock = { reactor.executeCallCount == 0 ? () : $0(nil) }
                reactor.shouldExecuteBlock = { _, _, _ in reactor.shouldExecuteCallCount == 0 }

                let manager = TaskManagerSpy(reactors: [reactor])
                manager.add(task: kDummyTask)

                // Wait till done callback passed to execute is captured
                ensure(reactor.executeCallData.count).becomes(1)

                // Run tasks that ask to be reactored and then not
                var handles: [(TaskHandle, TaskSpy<Void>)] = []
                for _ in (0..<50).yielded(by: .milliseconds(1)) {
                    let task = TaskSpy { $0(.success(())) }
                    handles.append((manager.add(task: task), task))
                }

                for (handle, task) in handles {
                    ensure(handle.state).becomes(.pending)
                    expect(task.executeCallCount) == 0
                }

                reactor.executeCallData[0](nil)

                ensure(manager.completionCallCount).becomes(handles.count + 1)

                for (handle, task) in handles {
                    expect(handle.state) == TaskState.finished
                    expect(task.executeCallCount) == 1
                }
            }
        }
    }
}
