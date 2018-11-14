import Foundation

open class AsyncOperation: Operation {
    private let lock: NSLocking = NSLock()

    #if DEBUG
        static var counter = AtomicInt()
    #endif

    public static let queue = DispatchQueue(label: "Swooft.AsyncOperation", attributes: [.concurrent])

    public enum State {
        case ready
        case executing
        case finished
    }

    public var state: State {
        return self.lock.withScope {
            let currentState: State
            if _finished {
                currentState = .finished
            } else if _executing {
                currentState = .executing
            } else {
                currentState = .ready
            }
            log(level: .debug, from: self, "\(self) getting state \(currentState)")
            return currentState
        }
    }

    let executor: (AsyncOperation) -> Void

    public init(executor: @escaping (AsyncOperation) -> Void) {
        self.executor = executor
        super.init()
        #if DEBUG
            self.name = "asyncop.\(AsyncOperation.counter.getAndIncrement())"
        #endif
    }

    #if DEBUG
        deinit {
            AsyncOperation.counter.getAndDecrement()
        }
    #endif

    open override var isAsynchronous: Bool {
        return true
    }

    private enum KVOKey: String {
        case isExecuting, isFinished, isCancelled
    }

    private var _executing: Bool = false
    open private(set) override var isExecuting: Bool {
        get {
            return self.lock.withScope {
                log(level: .debug, from: self, "\(self) getting \(self._executing)")
                return self._executing
            }
        }
        set {
            willChangeValue(forKey: KVOKey.isExecuting.rawValue)
            self.lock.withScope {
                log(level: .debug, from: self, "set \(self) to \(newValue)")
                self._executing = newValue
            }
            didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        }
    }

    private var _finished: Bool = false
    open private(set) override var isFinished: Bool {
        get {
            return self.lock.withScope {
                log(level: .debug, from: self, "\(self) getting \(self._finished)")
                return self._finished
            }
        }
        set {
            willChangeValue(forKey: KVOKey.isFinished.rawValue)
            self.lock.withScope {
                log(level: .debug, from: self, "set \(self) to \(newValue)")
                self._finished = newValue
            }
            didChangeValue(forKey: KVOKey.isFinished.rawValue)
        }
    }

    open override func start() {
        log(from: self, "starting \(self)")
        guard !self.isCancelled else {
            log(from: self, "cancelled, aborting \(self)")
            self.isFinished = true
            return
        }
        log(from: self, "executing \(self)")
        self.isExecuting = true
        AsyncOperation.queue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.executor(strongSelf)
        }
    }

    open func finish() {
        willChangeValue(forKey: KVOKey.isExecuting.rawValue)
        willChangeValue(forKey: KVOKey.isFinished.rawValue)
        self.lock.withScope {
            log(level: .debug, from: self, "finishing \(self)")
            self._executing = false
            self._finished = true
        }
        didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        didChangeValue(forKey: KVOKey.isFinished.rawValue)
    }

    open override func cancel() {
        log(from: self, "cancelling \(self)")
        super.cancel()
        self.finish()
    }

    open override var description: String {
        #if DEBUG
            if let name = self.name {
                return name
            }
        #endif
        return super.description
    }
}
