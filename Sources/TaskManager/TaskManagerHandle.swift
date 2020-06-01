import Foundation

extension TaskManager {
    // A concrete handle to the type of task that TaskManager keeps a track of
    class Handle: Tasker.Handle {
        private weak var owner: TaskManager?

        public let identifier: Int

        static var counter = AtomicInt()

        #if DEBUG
            init() {
                self.identifier = type(of: self).counter.getAndIncrement()
                self.owner = nil
            }
        #endif

        init(owner: TaskManager) {
            self.identifier = type(of: self).counter.getAndIncrement()
            self.owner = owner
        }

        public func start() {
            self.owner?.start(handle: self)
        }

        public func cancel() {
            self.owner?.cancel(handle: self, with: .cancelled)
        }

        public var state: TaskState {
            self.owner?.taskState(for: self) ?? .finished
        }

        func discard() {
            self.owner?.cancel(handle: self, with: nil)
        }
    }
}

extension TaskManager.Handle: CustomStringConvertible {
    var description: String {
        let ownerIdentifier: String
        if let owner = self.owner {
            ownerIdentifier = "\(owner.identifier)."
        } else {
            ownerIdentifier = "<unowned>."
        }

        return "handle.\(ownerIdentifier)\(self.identifier)"
    }
}

extension TaskManager.Handle: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.identifier)
    }

    static func == (lhs: TaskManager.Handle, rhs: TaskManager.Handle) -> Bool {
        lhs.identifier == rhs.identifier
    }
}
