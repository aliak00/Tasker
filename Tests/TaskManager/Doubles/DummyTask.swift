import Foundation
import Tasker

class DummyTask: Task {
    typealias SuccessValue = Void
    func execute(completion: @escaping CompletionCallback) {
        completion(.success(()))
    }
}

// It's mutable because it's passed to inout funcitons.
var kDummyTask = DummyTask()
