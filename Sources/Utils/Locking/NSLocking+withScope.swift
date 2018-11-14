import Foundation

extension NSLocking {
    public func withScope<T>(block: () -> T) -> T {
        self.lock()
        defer { self.unlock() }
        return block()
    }
}
