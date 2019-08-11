import Foundation
@testable import Tasker

class TaskReactorDelegateSpy: TaskReactorManagerDelegate {

    var reactorsCompletedData: SynchronizedArray<Set<TaskManager.Handle>> = []
    func reactorsCompleted(handlesToRequeue: Set<TaskManager.Handle>) {
        self.reactorsCompletedData.append(handlesToRequeue)
    }

    var reactorFailedData: SynchronizedArray<(associatedHandles: Set<TaskManager.Handle>, error: TaskError)> = []
    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError) {
        self.reactorFailedData.append((associatedHandles, error))
    }
}

class TaskReactorManagerSpy {
    let reactorManager: TaskReactorManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<TaskReactorManager.ReactionResult> = []

    init(reactors: [TaskReactor] = []) {
        self.reactorManager = TaskReactorManager(reactors: reactors)
    }

    weak var delegate: TaskReactorDelegateSpy? {
        didSet {
            self.reactorManager.delegate = self.delegate
        }
    }

    func react(
        result: Result<Void, Error> = Result<Void, Error>.success(()),
        completion: @escaping (TaskReactorManager.ReactionResult) -> Void = { _ in }
    ) {
        let handle = TaskManager.Handle()
        let task = DummyTask()
        self.react(task: task, result: result, handle: handle, completion: completion)
    }

    func react<T: Task>(
        task: T,
        result: T.Result,
        handle: TaskManager.Handle,
        completion: @escaping (TaskReactorManager.ReactionResult) -> Void = { _ in }
    ) {
        self.reactorManager.react(task: task, result: result, handle: handle) { [weak self] result in
            defer {
                self?.completionCallData.append(result)
            }
            completion(result)
        }
    }
}
