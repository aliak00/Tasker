import Foundation

/**
 This is a handle to a task that is given to the `TaskManager` and can be used to control
 the task.
 */
public protocol TaskHandle: class {
    /// Cancels the task
    func cancel()
    /// Starts the task if it hasn't already been started
    func start()
    /// Retrieves the state of the task
    var state: TaskState { get }
    /// An auto incrementing ID for the task
    var identifier: Int { get }
}
