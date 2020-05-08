@testable import Tasker

class ReactorSpy: Reactor {
    let configuration: ReactorConfiguration

    init(configuration: ReactorConfiguration = .default) {
        self.configuration = configuration
    }

    var executeCallCount: Int {
        self.executeCallData.count
    }

    var executeCallData: SynchronizedArray<(Error?) -> Void> = []
    var executeBlock: (@escaping (Error?) -> Void) -> Void = { done in done(nil) }

    var shouldExecuteCallCount: Int {
        self.shouldExecuteCallData.count
    }

    var shouldExecuteCallData: SynchronizedArray<(anyResult: AnyResult, weakAnyTask: Weak<AnyObject>, handle: Handle)> = []
    var shouldExecuteBlock: (AnyResult, AnyObject, Handle) -> Bool = { _, _, _ in true }

    func execute(done: @escaping (Error?) -> Void) {
        self.executeCallData.append(done)
        self.executeBlock(done)
    }

    func shouldExecute<T>(after result: T.Result, from task: T, with handle: Handle) -> Bool where T: Task {
        let anyResult = AnyResult(result)
        self.shouldExecuteCallData.append((anyResult, Weak(task), handle))
        return self.shouldExecuteBlock(anyResult, task, handle)
    }
}
