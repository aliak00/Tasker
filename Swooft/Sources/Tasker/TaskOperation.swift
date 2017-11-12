/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

class TaskOperation: Operation {

    private let queue = DispatchQueue(label: "Swooft.Tasker.TaskOperation", attributes: [.concurrent])
    let executor: (_ operation: TaskOperation) -> Void

    enum State {
        case pending
        case ready
        case executing
        case finished

        var keyPath: String {
            switch self {
            case .ready:
                return "isReady"
            case .executing:
                return "isExecuting"
            case .finished:
                return "isFinished"
            case .pending:
                return "isPending"
            }
        }
    }

    private var _state: State = .pending
    private(set) var state: State {
        get {
            return self.queue.sync {
                return self._state
            }
        }

        set(newValue) {
            self.setState(to: newValue)
        }
    }

    @discardableResult
    private func setState(to newState: State, if pred: (State) -> Bool = { _ in true }) -> Bool {
        let oldValue = self.state
        guard oldValue != newState else {
            return false
        }

        willChangeValue(forKey: oldValue.keyPath)
        willChangeValue(forKey: newState.keyPath)
        let didSet = self.queue.sync(flags: .barrier) { () -> Bool in
            if pred(self._state) {
                self._state = newState
                return true
            }
            return false
        }
        if didSet {
            didChangeValue(forKey: oldValue.keyPath)
            didChangeValue(forKey: newState.keyPath)
        }
        return didSet
    }

    init(executor: @escaping (TaskOperation) -> Void) {
        self.executor = executor
    }

    public override func start() {
        if self.setState(to: .executing, if: { _ in !self.isCancelled } ) {
            self.queue.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.executor(strongSelf)
            }

        } else {
            self.state = .finished
        }
    }

    func markReady() {
        self.setState(to: .ready, if: { $0 == .pending && !self.isCancelled } )
    }

    func markFinished() {
        self.state = .finished
    }

    public override var isReady: Bool {
        return self.queue.sync {
            return super.isReady && self._state == .ready
        }
    }

    public override var isExecuting: Bool {
        return self.state == .executing
    }

    public override var isFinished: Bool {
        return self.state == .finished
    }

    public override var isAsynchronous: Bool {
        return true
    }

    var isPending: Bool {
        return self.state == .pending
    }
}
