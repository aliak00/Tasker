import Foundation

class AsyncOperation: Operation {
    enum ExecuteResult {
        case done
        case running
    }

    private let lock: NSLocking = NSLock()

    #if DEBUG
        static var identifierCounter = AtomicInt()
        static var referenceCounter = AtomicInt()
    #endif

    enum State: String {
        case pending = "isPending"
        case ready = "isReady"
        case executing = "isExecuting"
        case finished = "isFinished"
    }

    private var _state: State = .pending

    private(set) var state: State {
        get {
            self.lock.scope {
                self._state
            }
        }

        set {
            willChangeValue(forKey: newValue.rawValue)
            self.lock.scope {
                self._state = newValue
                log(level: .verbose, from: self, "set \(self).state to \(newValue)")
            }
            didChangeValue(forKey: newValue.rawValue)
        }
    }

    var execute: (() -> ExecuteResult)?

    override init() {
        super.init()
        #if DEBUG
            AsyncOperation.referenceCounter.getAndIncrement()
            self.name = "AsyncOp.\(AsyncOperation.identifierCounter.getAndIncrement())"
        #endif
    }

    #if DEBUG
        deinit {
            AsyncOperation.referenceCounter.getAndDecrement()
        }
    #endif

    override var isAsynchronous: Bool {
        true
    }

    override var isReady: Bool {
        self.state == .ready
    }

    override var isExecuting: Bool {
        self.state == .executing
    }

    override var isFinished: Bool {
        self.state == .finished
    }

    override func start() {
        assert(self.state == .ready || self.isCancelled)
        log(level: .debug, from: self, "starting \(self)")
        guard !self.isCancelled else {
            log(level: .debug, from: self, "cancelled, aborting \(self)")
            self.state = .finished
            return
        }
        log(level: .debug, from: self, "executing \(self)")
        self.state = .executing
        if case .done? = self.execute?() {
            self.finish()
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
