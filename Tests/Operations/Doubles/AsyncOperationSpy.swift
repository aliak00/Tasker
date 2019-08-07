import Foundation
@testable import Tasker

class AsyncOperationSpy: AsyncOperation {
    var executorCallCount: AtomicInt = 0
    var startCallCount: AtomicInt = 0
    var finishCallCount: AtomicInt = 0
    var cancelCallCount: AtomicInt = 0

    init(executeBlock: @escaping (AsyncOperation) -> AsyncOperation.ExecuteResult) {
        super.init()
        self.execute = { [unowned self] () -> AsyncOperation.ExecuteResult in
            defer {
                self.executorCallCount += 1
            }
            return executeBlock(self)
        }
    }

    override func start() {
        super.start()
        self.startCallCount += 1
    }

    override func finish() {
        super.finish()
        self.finishCallCount += 1
    }

    override func cancel() {
        super.cancel()
        self.cancelCallCount += 1
    }
}
