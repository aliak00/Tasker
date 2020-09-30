import Foundation
@testable import Tasker

class TaskManagerSpy {
    let taskManager: TaskManager

    var completionCallCount: Int {
        self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<AnyResult> = []

    init(interceptors: [Interceptor] = [], reactors: [Reactor] = []) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
    }

    @discardableResult
    func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        completion: T.CompletionCallback? = { _ in }
    ) -> Handle {
        self.taskManager.add(task: task, startImmediately: startImmediately, after: interval) { [weak self] result in
            self?.completionCallData.append(AnyResult(result))
            completion?(result)
        }
    }

    func waitTillAllTasksFinished() {
        self.taskManager.waitTillAllTasksFinished()
    }

    func setCompletion<T: Task>(
        task: T,
        handle: Tasker.Handle,
        completion: @escaping T.CompletionCallback
    ) {
        self.taskManager.setCompletion(task: task, handle: handle) { [weak self] result in
            self?.completionCallData.append(AnyResult(result))
            completion(result)
        }
    }
}
