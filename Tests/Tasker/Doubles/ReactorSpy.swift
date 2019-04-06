@testable import Tasker

class ReactorSpy: TaskReactor {
    let configuration: TaskReactorConfiguration

    init(configuration: TaskReactorConfiguration = .default) {
        self.configuration = configuration
    }

    var executeCallCount: Int {
        return self.executeCallData.count
    }

    var executeCallData: SynchronizedArray<(Error?) -> Void> = []
    var executeBlock: (@escaping (Error?) -> Void) -> Void = { _ in }

    var shouldExecuteCallCount: Int {
        return self.shouldExecuteCallData.count
    }
    var shouldExecuteCallData: SynchronizedArray<(anyResult: AnyResult, weakAnyTask: Weak<AnyObject>, handle: TaskHandle)> = []
    var shouldExecuteBlock: (AnyResult, AnyObject, TaskHandle) -> Bool = { _, _, _ in true }

    func execute(done: @escaping (Error?) -> Void) {
        defer {
            self.executeCallData.append(done)
        }
        self.executeBlock(done)
    }

    func shouldExecute<T>(after result: T.Result, from task: T, with handle: TaskHandle) -> Bool where T: Task {
        let anyResult = AnyResult(result)
        defer {
            self.shouldExecuteCallData.append((anyResult, Weak(task), handle))
        }
        return self.shouldExecuteBlock(anyResult, task, handle)
    }
}
