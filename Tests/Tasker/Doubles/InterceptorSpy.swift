@testable import Tasker

class InterceptorSpy: TaskInterceptor {
    var interceptCallCount: Int {
        return self.interceptCallData.count
    }

    var interceptCallData: SynchronizedArray<(anyTask: AnyObject, currentBatchCount: Int)> = []
    var interceptCallResultData: SynchronizedArray<InterceptCommand> = []
    var interceptBlock: (AnyObject, Int) -> InterceptCommand = { _, _ in .execute }

    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand {
        let result = self.interceptBlock(task, currentBatchCount)
        defer {
            self.interceptCallData.append((task, currentBatchCount))
            self.interceptCallResultData.append(result)
        }
        return result
    }
}
