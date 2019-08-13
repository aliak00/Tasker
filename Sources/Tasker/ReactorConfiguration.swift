import Foundation

/**
 A reactor configuration can be used to control how a reactor is executed, and what happens to tasks while the
 reactor is being executed.

 Every `TaskManager` has a queue of tasks and this queue keeps on growing as long as tasks are added to the manager.
 A reactor has the power to pause this queue while it is being executed and can also tell a manager to requeue
 any task that causes this reaction
 */
public struct ReactorConfiguration {
    let timeout: DispatchTimeInterval?
    let requeuesTask: Bool
    let suspendsTaskQueue: Bool

    /**
     Initializes a configuration

     - parameter timeout: how long before `execute` times out
     - parameter requeuesTask: should that task that causes this reaction be requeued
     - parameter suspendsQueue: should the task manager suspend execution of any further tasks until
        the reaction is complete
     */
    public init(
        timeout: DispatchTimeInterval? = nil,
        requeuesTask: Bool = false,
        suspendsTaskQueue: Bool = false
    ) {
        self.timeout = timeout
        self.requeuesTask = requeuesTask
        self.suspendsTaskQueue = suspendsTaskQueue
    }

    /**
     Default configuration has no timeout, doesn't requeue tasks and doesn't suspend the queue
     */
    public static let `default` = ReactorConfiguration()
}
