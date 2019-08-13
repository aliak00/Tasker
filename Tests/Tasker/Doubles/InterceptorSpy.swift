@testable import Tasker

class InterceptorSpy: Interceptor {
    var interceptCallCount: Int {
        return self.interceptCallData.count
    }

    // TODO: these thwo should be merged since they are always set together
    var interceptCallData: SynchronizedArray<(anyTask: AnyObject, currentBatchCount: Int)> = []
    var interceptCallResultData: SynchronizedArray<InterceptCommand> = []

    var interceptBlock: (inout AnyObject, Int) -> InterceptCommand = { _, _ in .execute }

    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand {
        self.interceptCallData.append((task, currentBatchCount))
        var anyObject = task as AnyObject
        let result = self.interceptBlock(&anyObject, currentBatchCount)
        self.interceptCallResultData.append(result)
        return result
    }
}
