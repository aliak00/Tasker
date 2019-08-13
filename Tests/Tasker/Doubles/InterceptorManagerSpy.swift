import Foundation
@testable import Tasker

class InterceptorManagerSpy {
    let interceptorManager: InterceptorManager

    var completionCallCount: Int {
        return self.completionCallData.count
    }

    var completionCallData: SynchronizedArray<InterceptorManager.InterceptionResult> = []

    init(interceptors: [Interceptor] = []) {
        self.interceptorManager = InterceptorManager(interceptors)
    }

    func intercept<T: Task>(
        task: inout T,
        for handle: TaskManager.Handle,
        completion: @escaping (InterceptorManager.InterceptionResult) -> Void = { _ in }
    ) {
        self.interceptorManager.intercept(task: &task, for: handle) { [weak self] result in
            self?.completionCallData.append(result)
            completion(result)
        }
    }
}
