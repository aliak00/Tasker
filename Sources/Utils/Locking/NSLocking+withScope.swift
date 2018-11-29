import Foundation

extension NSLocking {
    func scope<T>(block: () -> T) -> T {
        self.lock()
        defer { self.unlock() }
        return block()
    }
}
