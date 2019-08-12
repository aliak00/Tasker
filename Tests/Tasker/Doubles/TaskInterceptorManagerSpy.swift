import Foundation
@testable import Tasker

class TaskInterceptorManagerSpy {
    let interceptorManager: TaskInterceptorManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<TaskInterceptorManager.InterceptionResult> = []

    init(interceptors: [TaskInterceptor] = []) {
        self.interceptorManager = TaskInterceptorManager(interceptors)
    }

    func intercept<T: Task>(
        task: inout T,
        for handle: TaskManager.Handle,
        completion: @escaping (TaskInterceptorManager.InterceptionResult) -> Void = { _ in }
    ) {
        self.interceptorManager.intercept(task: &task, for: handle) { [weak self] result in
            self?.completionCallData.append(result)
            completion(result)
        }
    }
}
