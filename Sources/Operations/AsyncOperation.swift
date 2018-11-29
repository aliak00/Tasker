import Foundation

class AsyncOperation: Operation {
    private let lock: NSLocking = NSLock()

    #if DEBUG
        static var identifierCounter = AtomicInt()
    #endif

    static let queue = DispatchQueue(label: "Tasker.AsyncOperation", attributes: [.concurrent])

    public enum State {
        case ready
        case executing
        case finished
    }

    private var _state: State = .ready

    var state: State {
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

    init(executor: @escaping (AsyncOperation) -> Void) {
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

    override var isAsynchronous: Bool {
        return true
    }

    private enum KVOKey: String {
        case isExecuting, isFinished, isCancelled
    }

    private(set) override var isExecuting: Bool {
        get {
            return self.state == .executing
        }
        set {
            willChangeValue(forKey: KVOKey.isExecuting.rawValue)
            self.state = .executing
            didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        }
    }

    private(set) override var isFinished: Bool {
        get {
            return self.state == .finished
        }
        set {
            willChangeValue(forKey: KVOKey.isFinished.rawValue)
            self.state = .finished
            didChangeValue(forKey: KVOKey.isFinished.rawValue)
        }
    }

    override func start() {
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

    func finish() {
        log(level: .debug, from: self, "finishing \(self)")
        willChangeValue(forKey: KVOKey.isExecuting.rawValue)
        willChangeValue(forKey: KVOKey.isFinished.rawValue)
        self.state = .finished
        didChangeValue(forKey: KVOKey.isExecuting.rawValue)
        didChangeValue(forKey: KVOKey.isFinished.rawValue)
    }

    override func cancel() {
        super.cancel()
        if !isExecuting {
            self.finish()
        }
    }

    override var description: String {
        #if DEBUG
            if let name = self.name {
                return name
            }
        #endif
        return super.description
    }
}
