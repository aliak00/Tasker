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

    let executor: (_ operation: TaskOperation) -> Void

    //
    // Recursive lock is necessary here because our overrided getters lock and get the state
    // and our state setter sends out KVO notifactions that the NSOperationQueue reacts to
    // by querying our getters. If it's a normal lock we get a deadlock
    //
    private var lock = NSRecursiveLock()

    enum State {
        case pending
        case ready
        case executing
        case finished

        func keyPath() -> String {
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

    var state: State {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self._state
    }

    private var _state: State = .pending {
        willSet {
            guard self.state != newValue else {
                return
            }
            willChangeValue(forKey: newValue.keyPath())
            willChangeValue(forKey: self.state.keyPath())
        }
        didSet {
            guard self.state != oldValue else {
                return
            }
            didChangeValue(forKey: oldValue.keyPath())
            didChangeValue(forKey: self.state.keyPath())
        }
    }

    init(executor: @escaping (TaskOperation) -> Void) {
        self.executor = executor
    }

    public override func start() {
        // Set to execute only if not already cancelled
        do {
            self.lock.lock()
            defer { self.lock.unlock() }

            guard !self.isCancelled else {
                self._state = .finished
                return
            }

            self._state = .executing
        }

        self.executor(self)
    }

    func markReady() {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self._state == .pending && !self.isCancelled else {
            return
        }

        self._state = .ready
    }

    func markFinished() {
        self.lock.lock()
        defer { self.lock.unlock() }
        self._state = .finished
    }

    public override func cancel() {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard self._state != .finished && !self.isCancelled else {
            return
        }

        // This sets operation as ready if not there yet and ensures isCancelled returns true
        // which results in the queue calling start where a check for isCancelled sets the
        // operation's state to finished
        super.cancel()
    }

    public override var isReady: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        // Check super.ready because it reports on dependent operations
        return super.isReady && self._state == .ready
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
