import Foundation

public protocol TaskHandle: class {
    func cancel()
    func start()
    var state: TaskState { get }
    var identifier: Int { get }
}
