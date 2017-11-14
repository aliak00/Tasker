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

private struct UserProfile {
    var name: String
}

private class User {
    enum ID {
        case valid
        case invalid
    }

    var id: ID = .invalid
    var profile: UserProfile?
}

private struct UserDead: Error {}
private struct UserInvalid: Error {}
private struct RandomFailure: Error {}

private protocol Retriable {
    var maxRetryCount: Int { get }
}

private protocol UserDependent {
    var weakUser: Weak<User> { get }
}

private class UserTask: Task, UserDependent, Retriable {
    typealias SuccessValue = Void
    var weakUser: Weak<User>
    let maxRetryCount = 3
    init(user: User) {
        self.weakUser = Weak(user)
    }

    func execute(completion: @escaping ResultCallback) {
        guard self.weakUser.value?.id == .valid else {
            completion(.failure(UserInvalid()))
            return
        }
        guard arc4random_uniform(2) != 0 else {
            completion(.failure(RandomFailure()))
            return
        }
        completion(.success(()))
    }
}

private class GetProfileTask: Task, UserDependent {
    typealias SuccessValue = UserProfile
    var weakUser: Weak<User>
    let profile: UserProfile
    init(user: User, profile: UserProfile = UserProfile(name: "Abe")) {
        self.weakUser = Weak(user)
        self.profile = profile
    }

    func execute(completion: @escaping ResultCallback) {
        guard let user = self.weakUser.value, user.id == .valid else {
            completion(.failure(UserInvalid()))
            return
        }

        completion(.success(self.profile))
    }
}

// This interceptor will take any task that is UserDependent and then if it's own
// internal user is still present, will set set the user in the task to something
// valid and re-execute
private class ValidateUserReactor: TaskReactor {

    weak var user: User?
    init(user: User) {
        self.user = user
    }

    var configuration: TaskReactorConfiguration {
        return TaskReactorConfiguration(isImmediate: false, requeuesTask: true, suspendsTaskQueue: true)
    }

    func shouldExecute<T>(after result: Result<T.SuccessValue>, from task: T, with _: TaskHandle) -> Bool where T: Task {
        return result.failureValue is UserInvalid && (task as? UserDependent)?.weakUser.value === self.user
    }

    func execute(done: @escaping (Error?) -> Void) {
        guard let user = self.user else {
            done(UserDead())
            return
        }
        user.id = .valid
        done(nil)
    }
}

// This interceptor will take any task that is retriable, and re-execute it
private class RetryReactor: TaskReactor {
    var counter: [Int: Int] = [:]

    var configuration: TaskReactorConfiguration {
        return TaskReactorConfiguration(isImmediate: true, requeuesTask: true, suspendsTaskQueue: false)
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

class ScenarioValidatingRetryingTests: QuickSpec {

    override func spec() {

        it("should all work") {

            // Ensure user starts off as invalid
            let user = User()
            expect(user.id) == User.ID.invalid

            // Create manager that validates and retries
            let manager = TaskManagerSpy(reactors: [ValidateUserReactor(user: user), RetryReactor()])

            // Run tasks that fail randomly
            let numTasks = 20
            for _ in (0..<numTasks).yielded(by: .milliseconds(1)) {
                manager.add(task: UserTask(user: user))
            }

            // All of them should have completed (after retries/refresh) and user should be valid
            ensure(manager.completionCallCount).becomes(numTasks)
            expect(user.id) == User.ID.valid

            // Invalidate user and try GetProfileTask
            user.id = .invalid
            let profile = UserProfile(name: "Jimbo")
            var returnedResult: GetProfileTask.TaskResult!
            let handle = manager.add(task: GetProfileTask(user: user, profile: profile)) { result in
                returnedResult = result
            }

            // Profile result shuld be expected and user should be valid
            ensure(handle.state).becomes(TaskState.finished)
            expect(returnedResult.successValue?.name) == profile.name
            expect(user.id) == User.ID.valid
        }
    }
}
