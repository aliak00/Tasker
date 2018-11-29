import Foundation

open class AsyncOperation: Operation {
    private let lock: NSLocking = NSLock()

    #if DEBUG
        static var identifierCounter = AtomicInt()
    #endif

    public static let queue = DispatchQueue(label: "Tasker.AsyncOperation", attributes: [.concurrent])

    public enum State {
        case ready
        case executing
        case finished
    }

    private var _state: State = .ready

    public var state: State {
        get {
            return self.lock.scope {
                return self._state
            }
        }

        set {
            self.lock.scope {
                self._state = newValue
            }
        }
    }

    let executor: (AsyncOperation) -> Void

    public init(executor: @escaping (AsyncOperation) -> Void) {
        self.executor = executor
        super.init()
        #if DEBUG
            self.name = "asyncop.\(AsyncOperation.identifierCounter.getAndIncrement())"
        #endif
    }

    #if DEBUG
        deinit {
            AsyncOperation.identifierCounter.getAndDecrement()
        }
    #endif

    open override var isAsynchronous: Bool {
        return true
    }

    private enum KVOKey: String {
        case isExecuting, isFinished, isCancelled
    }

    open private(set) override var isExecuting: Bool {
        get {
            return self.state == .executing
        }
        set {
            willChangeValue(forKey: KVOKey.isExecuting.rawValue)
            self.state = .executing
            didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        }
    }

    open private(set) override var isFinished: Bool {
        get {
            return self.state == .finished
        }
        set {
            willChangeValue(forKey: KVOKey.isFinished.rawValue)
            self.state = .finished
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
        log(level: .debug, from: self, "finishing \(self)")
        willChangeValue(forKey: KVOKey.isExecuting.rawValue)
        willChangeValue(forKey: KVOKey.isFinished.rawValue)
        self.state = .finished
        didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        didChangeValue(forKey: KVOKey.isFinished.rawValue)
    }

    open override func cancel() {
        super.cancel()
        if !isExecuting {
            self.finish()
        }
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
