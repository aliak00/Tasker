//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

class AsyncOperation: Operation {
    private let lock: NSLocking = NSLock()

    static let sharedQueue = DispatchQueue(label: "Swooft.Operation", attributes: [.concurrent])

    enum State {
        case ready
        case executing
        case finished
    }

    var state: State {
        return self.lock.withScope {
            if _finished {
                return .finished
            }
            if _executing {
                return .executing
            }
            return .ready
        }
    }

    let executor: (AsyncOperation) -> Void

    init(executor: @escaping (AsyncOperation) -> Void) {
        self.executor = executor
    }

    override var isAsynchronous: Bool {
        return true
    }

    private enum KVOKey: String {
        case isExecuting, isFinished, isCancelled
    }

    private var _executing: Bool = false
    private(set) override var isExecuting: Bool {
        get {
            return self.lock.withScope {
                self._executing
            }
        }

        set {
            willChangeValue(forKey: KVOKey.isExecuting.rawValue)
            let didSet = self.lock.withScope { () -> Bool in
                if self._executing != newValue {
                    self._executing = newValue
                    return true
                }
                return false
            }
            if didSet {
                didChangeValue(forKey: KVOKey.isExecuting.rawValue)
            }
        }
    }

    private var _finished: Bool = false
    private(set) override var isFinished: Bool {
        get {
            return self.lock.withScope {
                self._finished
            }
        }
        set {
            willChangeValue(forKey: KVOKey.isFinished.rawValue)
            let didSet = self.lock.withScope { () -> Bool in
                if self._finished != newValue {
                    self._finished = newValue
                    return true
                }
                return false
            }
            if didSet {
                didChangeValue(forKey: KVOKey.isFinished.rawValue)
            }
        }
    }

    override func start() {
        willChangeValue(forKey: KVOKey.isExecuting.rawValue)
        willChangeValue(forKey: KVOKey.isFinished.rawValue)
        let didSet = self.lock.withScope { () -> (executing: Bool, finished: Bool) in
            if self.isCancelled {
                self._finished = true
                return (false, true)
            } else {
                self._executing = true
                return (true, false)
            }
        }
        if didSet.executing {
            didChangeValue(forKey: KVOKey.isExecuting.rawValue)
            AsyncOperation.sharedQueue.async { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.executor(strongSelf)
            }
        }
        if didSet.finished {
            didChangeValue(forKey: KVOKey.isFinished.rawValue)
        }
    }

    func finish() {
        willChangeValue(forKey: KVOKey.isExecuting.rawValue)
        willChangeValue(forKey: KVOKey.isFinished.rawValue)
        let didSet = self.lock.withScope { () -> (executing: Bool, finished: Bool) in
            var didSetExecuting = false
            var didSetFinished = false
            if self._executing {
                self._executing = false
                didSetExecuting = true
            }
            if !self._finished {
                self._finished = true
                didSetFinished = true
            }
            return (didSetExecuting, didSetFinished)
        }
        if didSet.executing {
            didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        }
        if didSet.finished {
            didChangeValue(forKey: KVOKey.isFinished.rawValue)
        }
    }

    override func cancel() {
        super.cancel()
        willChangeValue(forKey: KVOKey.isExecuting.rawValue)
        willChangeValue(forKey: KVOKey.isFinished.rawValue)
        let didSet = self.lock.withScope { () -> Bool in
            if self._executing {
                self._finished = true
                self._executing = false
                return true
            }
            return false
        }
        if didSet {
            didChangeValue(forKey: KVOKey.isExecuting.rawValue)
            didChangeValue(forKey: KVOKey.isFinished.rawValue)
        }
    }
}
