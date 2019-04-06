import Foundation
import Tasker

class DummyTask: Task {
    typealias SuccessValue = Void
    func execute(completion: @escaping CompletionCallback) {
        completion(.success(()))
    }
}

let kDummyTask = DummyTask()
