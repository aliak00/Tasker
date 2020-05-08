import Foundation
@testable import Tasker

class ReactorManagerSpy {
    let reactorManager: ReactorManager

    var completionCallCount: Int {
        self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<ReactorManager.ReactionResult> = []

    init(reactors: [Reactor] = []) {
        self.reactorManager = ReactorManager(reactors: reactors)
    }

    weak var delegate: ReactorManagerDelegateSpy? {
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
