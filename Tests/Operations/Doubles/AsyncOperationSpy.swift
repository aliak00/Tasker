import Foundation
import Tasker

class AsyncOperationSpy: AsyncOperation {
    var executorCallCount: AtomicInt = 0
    var startCallCount: AtomicInt = 0
    var finishCallCount: AtomicInt = 0
    var cancelCallCount: AtomicInt = 0

    override init(executor: @escaping (AsyncOperation) -> Void) {
        super.init { op in
            executor(op)
            (op as! AsyncOperationSpy).executorCallCount += 1
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
