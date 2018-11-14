import Foundation

extension TaskManager {
    class Handle: TaskHandle {
        private weak var owner: TaskManager?

        public let identifier: Int

        static var counter = AtomicInt()

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
            return self.owner?.taskState(for: self) ?? .finished
        }

        func discard() {
            self.owner?.cancel(handle: self, with: nil)
        }
    }
}

extension TaskManager.Handle: CustomStringConvertible {
    var description: String {
        var ownerIdentifier: String = "<unowned>."
        if let owner = self.owner {
            ownerIdentifier = "\(owner.identifier)."
        }

        return "handle.\(ownerIdentifier)\(self.identifier)"
    }
}

extension TaskManager.Handle: Hashable {
    var hashValue: Int {
        return self.identifier
    }

    static func == (lhs: TaskManager.Handle, rhs: TaskManager.Handle) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
