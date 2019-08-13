import Foundation
@testable import Tasker

class TaskReactorDelegateSpy: ReactorManagerDelegate {

    typealias ReactorsCompletedData = (Set<TaskManager.Handle>)
    var reactorsCompletedData: SynchronizedArray<ReactorsCompletedData> = []
    func reactorsCompleted(handlesToRequeue: Set<TaskManager.Handle>) {
        self.reactorsCompletedData.append(ReactorsCompletedData(handlesToRequeue))
    }

    typealias ReactorFailedData = (associatedHandles: Set<TaskManager.Handle>, error: TaskError)
    var reactorFailedData: SynchronizedArray<ReactorFailedData> = []
    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError) {
        self.reactorFailedData.append(ReactorFailedData(associatedHandles, error))
    }
}

class TaskReactorManagerSpy {
    let reactorManager: ReactorManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<ReactorManager.ReactionResult> = []

    init(reactors: [Reactor] = []) {
        self.reactorManager = ReactorManager(reactors: reactors)
    }

    weak var delegate: TaskReactorDelegateSpy? {
        didSet {
            self.reactorManager.delegate = self.delegate
        }
    }

    @discardableResult
    func react(
        result: Result<Void, Error> = Result<Void, Error>.success(()),
        completion: @escaping (ReactorManager.ReactionResult) -> Void = { _ in }
    ) -> TaskManager.Handle {
        let handle = TaskManager.Handle()
        let task = DummyTask()
        self.react(task: task, result: result, handle: handle, completion: completion)
        return handle
    }

    func react<T: Task>(
        task: T,
        result: T.Result,
        handle: TaskManager.Handle,
        completion: @escaping (ReactorManager.ReactionResult) -> Void = { _ in }
    ) {
        self.reactorManager.react(task: task, result: result, handle: handle) { [weak self] result in
            self?.completionCallData.append(result)
            completion(result)
        }
    }
}
