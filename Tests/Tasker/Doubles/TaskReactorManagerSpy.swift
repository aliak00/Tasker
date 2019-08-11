import Foundation
@testable import Tasker

class WrappedTaskReactorDelegate: TaskReactorManagerDelegate {
    weak var delegate: TaskReactorManagerDelegate?

    init(_ delegate: TaskReactorManagerDelegate) {
        self.delegate = delegate
    }

    var reactorsCompletedData: SynchronizedArray<Set<TaskManager.Handle>> = []
    func reactorsCompleted(handlesToRequeue: Set<TaskManager.Handle>) {
        self.delegate?.reactorsCompleted(handlesToRequeue: handlesToRequeue)
        self.reactorsCompletedData.append(handlesToRequeue)
    }

    var reactorFailedData: SynchronizedArray<(associatedHandles: Set<TaskManager.Handle>, error: TaskError)> = []
    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError) {
        self.delegate?.reactorFailed(associatedHandles: associatedHandles, error: error)
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

    var delegate: WrappedTaskReactorDelegate? {
        didSet {
            self.reactorManager.delegate = self.delegate
        }
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
