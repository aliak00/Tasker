@testable import Tasker
import XCTest

// Simulates a hippopotamus that may be alive or dead
private class Hippo {
    enum Status {
        case alive
        case dead
    }

    private var _status = Atomic<Status>(.dead)
    private var _name = Atomic<String?>(nil)

    var status: Status {
        get {
            self._status.value
        }
        set {
            self._status.value = newValue
        }
    }

    var name: String? {
        get {
            self._name.value
        }
        set {
            self._name.value = newValue
        }
    }
}

// These are the different errors that may be encountered in this simulation
private enum HippoError: Error {
    case unrevivable
    case dead
    case random
}

// This simulates any task that can be retried
private protocol Retriable {
    var maxRetryCount: Int { get }
}

// This simulates a protocol that must be implemented for any task that depends on an alive hippo
private protocol HasHippo {
    var weakHippo: Weak<Hippo> { get }
}

// Simulates a task that depends on a live hippo and can be retried if it fails.
private class EatGook: Task, HasHippo, Retriable {
    typealias SuccessValue = Void

    var weakHippo: Weak<Hippo>
    let maxRetryCount = 3

    init(hippo: Hippo) {
        self.weakHippo = Weak(hippo)
    }

    func execute(completion: @escaping CompletionCallback) {
        // Hippo must be alive
        guard self.weakHippo.value?.status == .alive else {
            completion(.failure(HippoError.dead))
            return
        }
        // Simulate some random failure that could result from whatever - 50/50 chance
        guard arc4random_uniform(2) == 0 else {
            completion(.failure(HippoError.random))
            return
        }
        // Yay, success, the hippo ate gook
        completion(.success(()))
    }
}

// This simulates doing something that just needs a hippo, but cannot be retried
private class GetName: HasHippo, Task {
    typealias SuccessValue = String
    var weakHippo: Weak<Hippo>
    init(hippo: Hippo) {
        self.weakHippo = Weak(hippo)
    }

    func execute(completion: @escaping CompletionCallback) {
        guard let hippo = self.weakHippo.value, hippo.status == .alive, let name = hippo.name else {
            completion(.failure(HippoError.dead))
            return
        }

        completion(.success(name))
    }
}

private class ReviveTheHippoReactor: Reactor {
    init() {}
    var configuration: ReactorConfiguration {
        ReactorConfiguration(requeuesTask: true, suspendsTaskQueue: true)
    }

    weak var hippo: Hippo?

    func shouldExecute<T: Task>(after result: T.Result, from task: T, with _: Handle) -> Bool {
        guard let hippoTask = task as? HasHippo else {
            return false
        }
        guard case HippoError.dead? = result.failureValue else {
            return false
        }
        self.hippo = hippoTask.weakHippo.value
        self.hippo?.status = .alive
        return true
    }

    func execute(done: @escaping (Error?) -> Void) {
        guard let hippo = self.hippo else {
            done(HippoError.unrevivable)
            return
        }
        hippo.status = .alive
        done(nil)
    }
}

// This interceptor will take any task that is retriable, and re-execute it
private class RetryReactor: Reactor {
    var counter = SynchronizedDictionary<Int, Int>()

    var configuration: ReactorConfiguration {
        ReactorConfiguration(requeuesTask: true, suspendsTaskQueue: true)
    }

    func shouldExecute<T>(after result: T.Result, from task: T, with handle: Handle) -> Bool where T: Task {
        guard case HippoError.random? = result.failureValue, let task = task as? Retriable else {
            return false
        }
        guard let count = self.counter[handle.identifier] else {
            self.counter[handle.identifier] = 1 // first retry
            return true
        }
        guard count < task.maxRetryCount else {
            return false
        }
        self.counter[handle.identifier] = count + 1
        return true
    }
}

class ScenarioValidatingRetryingTests: XCTestCase {
    func testDefaultHippoIsDead() {
        let hippo = Hippo()
        XCTAssertEqual(hippo.status, Hippo.Status.dead)
    }

    func testShouldAllWork() {
        var hippos: [Hippo] = []

        let retryReactor = RetryReactor()
        let reviveTheHippoReactor = ReviveTheHippoReactor()
        // Create manager that validates and retries
        let manager = TaskManagerSpy(reactors: [reviveTheHippoReactor, retryReactor])

        // Try and eat a bunch of times. The hippo will be dead first, the revive reactor will bring it back
        // and then the hippo may or may not eat
        let numTasks = 20
        for _ in (0 ..< numTasks).yielded(by: .milliseconds(1)) {
            let hippo = Hippo()
            hippos.append(hippo)
            manager.add(task: EatGook(hippo: hippo))
        }

        // All of them should have completed retries and all the hippos should be alive
        ensure(manager.completionCallCount).becomes(numTasks)
        for hippo in hippos {
            XCTAssertEqual(hippo.status, .alive)
        }

        // Kill all hippos, set a name, and get it, store handles
        var handles = [Handle]()
        let results = SynchronizedArray<GetName.Result>()
        for hippo in hippos {
            hippo.status = .dead
            hippo.name = "Jimbo"
            let handle = manager.add(task: GetName(hippo: hippo)) { result in
                results.append(result)
            }
            handles.append(handle)
        }

        manager.waitTillAllTasksFinished()

        for handle in handles {
            ensure(handle.state).becomes(.finished)
        }

        for hippo in hippos {
            XCTAssertEqual(hippo.status, .alive)
        }

        for result in results.data {
            XCTAssertEqual(result.successValue, "Jimbo")
        }
    }
}
