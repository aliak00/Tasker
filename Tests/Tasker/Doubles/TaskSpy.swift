import Foundation
@testable import Tasker

var kTaskSpyCounter = AtomicInt()

class TaskSpy<T>: AnyTask<T> {
    var executeCallCount: Int {
        return self.executeCallBackData.count
    }

    var executeCallBackData: SynchronizedArray<AnyResult> = []

    override init(timeout: DispatchTimeInterval? = nil, execute: (@escaping (@escaping ResultCallback) -> Void)) {
        super.init(timeout: timeout, execute: execute)
        kTaskSpyCounter.getAndIncrement()
    }

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> Result<T>) {
        self.init(timeout: timeout) { completion in
            completion(execute())
        }
    }

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> T) {
        self.init(timeout: timeout) { completion in
            completion(.success(execute()))
        }
    }

    // TODO: Uncomment when bug fixed: https://bugs.swift.org/browse/SR-8142
//    convenience init<U: Task>(_ task: U) where U.SuccessValue == SuccessValue {
//        self.init(timeout: task.timeout) { completion in
//            task.execute(completion: completion)
//        }
//    }

    deinit {
        kTaskSpyCounter.getAndDecrement()
    }

    override func execute(completion: @escaping ResultCallback) {
        let wrappedCompletion: ResultCallback = { [weak self] result in
            completion(result)
            self?.executeCallBackData.append(AnyResult(result))
        }
        self.executeThunk(wrappedCompletion)
    }
}
