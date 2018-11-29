@testable import Tasker
import XCTest

// Simulates a human being that may be alive or dead
private class Hippo {
    enum Status {
        case alive
        case dead
    }

    var status: Status = .dead
    var name: String?
}

// These are the different errors that may be encountered in this simulation
private struct Unrevivable: Error {}
private struct Dead: Error {}
private struct RandomFailure: Error {}

// This simulates any task that can be retried
private protocol Retriable {
    var maxRetryCount: Int { get }
}

// This simulates a protocol that must be implemented for any task that depends on an alive hippo
private protocol HippoRequired {
    var weakHippo: Weak<Hippo> { get }
}

// Simulates a task that depends on a live hippo and can be retried if it fails.
private class EatGobbledygook: Task, HippoRequired, Retriable {
    typealias SuccessValue = Void

    var weakHippo: Weak<Hippo>
    let maxRetryCount = 3

    init(hippo: Hippo) {
        self.weakHippo = Weak(hippo)
    }

    func execute(completion: @escaping ResultCallback) {
        // Hippo must be alive
        guard self.weakHippo.value?.status == .alive else {
            completion(.failure(Dead()))
            return
        }
        // Simulate some random failure that could result from whatever
        guard arc4random_uniform(2) != 0 else {
            completion(.failure(RandomFailure()))
            return
        }
        // Yay, success, the hippo gobbldygooked
        completion(.success(()))
    }
}

// This simulates doing something that just needs a hippo, but cannot be retried
private class GetHippoNameTask: Task, HippoRequired {

    typealias SuccessValue = String
    var weakHippo: Weak<Hippo>
    let name: String
    init(hippo: Hippo, name: String = "Abe") {
        self.weakHippo = Weak(hippo)
        self.name = name
    }

    func execute(completion: @escaping ResultCallback) {
        guard let hippo = self.weakHippo.value, hippo.status == .alive else {
            completion(.failure(Dead()))
            return
        }

        completion(.success(self.name))
    }
}

// This reactor will take any task that is UserDependent and then if it's own
// internal user is still present, will set set the user in the task to something
// valid and re-execute
private class ReviveTheHippoReactor: TaskReactor {
    weak var hippo: Hippo?
    init(hippo: Hippo) {
        self.hippo = hippo
    }

    var configuration: TaskReactorConfiguration {
        return TaskReactorConfiguration(requeuesTask: true, suspendsTaskQueue: true)
    }

    func shouldExecute<T>(after result: Result<T.SuccessValue>, from _: T, with _: TaskHandle) -> Bool where T: Task {
        return result.failureValue is Dead
    }

    func execute(done: @escaping (Error?) -> Void) {
        guard let hippo = self.hippo else {
            done(Unrevivable())
            return
        }
        hippo.status = .alive
        done(nil)
    }
}

// This interceptor will take any task that is retriable, and re-execute it
private class RetryReactor: TaskReactor {
    var counter: [Int: Int] = [:]

    var configuration: TaskReactorConfiguration {
        return TaskReactorConfiguration(requeuesTask: true, suspendsTaskQueue: true)
    }

    func shouldExecute<T>(after result: Result<T.SuccessValue>, from task: T, with handle: TaskHandle) -> Bool where T: Task {
        if result.failureValue is RandomFailure, let task = task as? Retriable {
            guard task.maxRetryCount > 0 else {
                return false
            }
            guard let count = self.counter[handle.identifier] else {
                self.counter[handle.identifier] = 0
                return true
            }
            guard count < task.maxRetryCount else {
                self.counter.removeValue(forKey: handle.identifier)
                return false
            }
            self.counter[handle.identifier] = count + 1
            return true
        }
        return false
    }
}

class ScenarioValidatingRetryingTests: XCTestCase {
    func testShouldAllWork() {
        let hippo = Hippo()
        XCTAssertEqual(hippo.status, Hippo.Status.dead)

        // Create manager that validates and retries
        let manager = TaskManagerSpy(reactors: [ReviveTheHippoReactor(hippo: hippo), RetryReactor()])

        // Run tasks that should fail randomly
        let numTasks = 20
        for _ in (0..<numTasks).yielded(by: .milliseconds(1)) {
            manager.add(task: EatGobbledygook(hippo: hippo))
        }

        // All of them should have completed retries and all the hippo should be alive
        ensure(manager.completionCallCount).becomes(numTasks)
        XCTAssertEqual(hippo.status, Hippo.Status.alive)

        // Kill hippo and try to get it's name
        hippo.status = .dead
        let name = "Jimbo"
        var returnedResult: GetHippoNameTask.Result?
        let handle = manager.add(task: GetHippoNameTask(hippo: hippo, name: name)) { result in
            returnedResult = result
        }

        // Name result should be expected and hippo should be alive
        manager.waitTillAllTasksFinished()
        ensure(handle.state).becomes(TaskState.finished)
        XCTAssertEqual(returnedResult?.successValue, name)
        XCTAssertEqual(hippo.status, Hippo.Status.alive)
    }
}
