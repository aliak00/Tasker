/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Quick
import Nimble

@testable import Swooft

class TaskInterceptorTests: QuickSpec {
    override func spec() {

        describe("task manager") {

            it("should run interceptor") {
                let interceptor = InterceptorSpy()
                let manager = TaskManagerSpy(interceptors: [interceptor])
                manager.add(task: kDummyTask)
                ensure(interceptor.interceptCallCount).becomes(1)
            }

            it("should cancel interceptor on timeout") {
                let interceptor = InterceptorSpy(configuration: TaskInterceptorConfiguration(timeout: .milliseconds(5), requeuesTask: true))
                interceptor.executeBlock = { sleep(for: .milliseconds(10)); $0(nil) }
                let manager = TaskManagerSpy(interceptors: [interceptor])
                manager.add(task: SuccessTaskSpy())
                ensure(manager.completionHandlerCallCount).becomes(1)
                expect(manager.completionHandlerCallData[0]).to(failWith(TaskError.interceptorTimedOut("")))
            }

            it("should complete interceptor if under timeout") {
                let interceptor = InterceptorSpy(configuration: TaskInterceptorConfiguration(timeout: .milliseconds(10)))
                interceptor.executeBlock = { sleep(for: .milliseconds(5)); $0(nil) }
                let manager = TaskManagerSpy(interceptors: [interceptor])
                manager.add(task: SuccessTaskSpy())
                ensure(manager.completionHandlerCallCount).becomes(1)
                expect(manager.completionHandlerCallData[0]).toNot(failWith(TaskError.interceptorTimedOut("")))
            }

            it("should re-execute tasks if interceptor says requeue") {
                let interceptor = InterceptorSpy(configuration: TaskInterceptorConfiguration(requeuesTask: true))
                interceptor.executeBlock = { done in
                    sleep(for: .milliseconds(1))
                    done(nil)
                }
                interceptor.shouldExecuteBlock = { anyResult, anyTask, _ in
                    guard (anyTask.internalTask as! TaskSpy<Int>).executeCallBackData.count == 1 else {
                        return false
                    }
                    return (anyResult.successValue! as! Int) % 2 == 0
                }

                let manager = TaskManagerSpy(interceptors: [interceptor])

                // Run tasks that ask to be intercepted and then not
                let numTasks = 4
                var tasks: [TaskSpy<Int>] = []
                for i in (0..<numTasks).yielded(by: .milliseconds(1)) {
                    let task = TaskSpy { $0(.success(i)) }
                    tasks.append(task)
                    manager.add(task: task)
                }

                ensure(manager.completionHandlerCallCount).becomes(numTasks)

                for (index, task) in tasks.enumerated() {
                    if index % 2 == 0 {
                        expect(task.executeCallCount) == 2
                    } else {
                        expect(task.executeCallCount) == 1
                    }
                }
            }

            it("should not start complete tasks till after interceptor is completed") {
                let interceptor = InterceptorSpy(configuration: TaskInterceptorConfiguration(requeuesTask: true, suspendsTaskQueue: true))

                // First let it hang, it should pause the queue then we can call the callback later to finish the interceptor
                interceptor.executeBlock = { interceptor.executeCallCount == 0 ? () : $0(nil) }
                interceptor.shouldExecuteBlock = { _ in interceptor.shouldExecuteCallCount == 0 }

                let manager = TaskManagerSpy(interceptors: [interceptor])
                manager.add(task: kDummyTask)

                // Wait till done callback passed to execute is captured
                ensure(interceptor.executeCallData.count).becomes(1)

                // Run tasks that ask to be intercepted and then not
                var handles: [(TaskHandle, SuccessTaskSpy)] = []
                for _ in (0..<50).yielded(by: .milliseconds(1)) {
                    let task = SuccessTaskSpy()
                    handles.append(manager.add(task: task), task)
                }

                for (handle, task) in handles {
                    expect(handle.state) == TaskState.executing
                    expect(task.executeCallCount) == 0
                }

                interceptor.executeCallData[0](nil)

                ensure(manager.completionHandlerCallCount).becomes(handles.count + 1)

                for (handle, task) in handles {
                    expect(handle.state) == TaskState.finished
                    expect(task.executeCallCount) == 1
                }
            }
        }

        describe("interceptor") {

            it("should be called with task") {
                let interceptor = InterceptorSpy()
                let manager = TaskManagerSpy(interceptors: [interceptor])
                let task = SuccessTaskSpy()
                manager.add(task: task)
                ensure(interceptor.interceptCallCount).becomes(1)
                expect(interceptor.interceptCallData[0].weakAnyTask.anyTask) === task
            }
        }
    }
}
