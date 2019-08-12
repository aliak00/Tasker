import Foundation
@testable import Tasker

class TaskManagerSpy {
    let taskManager: TaskManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<AnyResult> = []

    init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = []) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
    }

    @discardableResult
    func add<T: Task>(
        task: T,
        startImmediately: Bool = true,
        after interval: DispatchTimeInterval? = nil,
        completion: (@escaping (T.Result) -> Void) = { _ in }
    ) -> TaskHandle {
        return self.taskManager.add(task: task, startImmediately: startImmediately, after: interval) { [weak self] result in
            self?.completionCallData.append(AnyResult(result))
            completion(result)
        }
    }

    func waitTillAllTasksFinished() {
        return self.taskManager.waitTillAllTasksFinished()
    }
}
