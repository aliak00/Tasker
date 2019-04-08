import Foundation

class AsyncOperation: Operation {
    private let lock: NSLocking = NSLock()

    #if DEBUG
        static var identifierCounter = AtomicInt()
    #endif

    static let queue = DispatchQueue(label: "Tasker.AsyncOperation", attributes: [.concurrent])

    enum State: String {
        case pending = "isPending"
        case ready = "isReady"
        case executing = "isExecuting"
        case finished = "isFinished"
    }

    private var _state: State = .pending

    private(set) var state: State {
        get {
            return self.lock.scope {
                self._state
            }
        }

        set {
            willChangeValue(forKey: newValue.rawValue)
            self.lock.scope {
                self._state = newValue
            }
            didChangeValue(forKey: newValue.rawValue)
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

    override var isReady: Bool {
        return self.state == .ready
    }

    override var isExecuting: Bool {
        return self.state == .executing
    }

    override var isFinished: Bool {
        return self.state == .finished
    }

    override func start() {
        assert(self.state == .ready || self.isCancelled)
        log(from: self, "starting \(self)")
        guard !self.isCancelled else {
            log(from: self, "cancelled, aborting \(self)")
            self.state = .finished
            return
        }
        log(from: self, "executing \(self)")
        self.state = .executing
        AsyncOperation.queue.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.executor(strongSelf)
        }
    }

    func finish() {
        log(level: .debug, from: self, "finishing \(self)")
        self.state = .finished
    }

    func markReady() {
        assert(self.state == .pending)
        log(level: .debug, from: self, "readying \(self)")
        self.state = .ready
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
