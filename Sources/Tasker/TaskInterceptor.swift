import Foundation

/**
 A command that can be returned by a `TaskInterceptor` intercept call that tells a `TaskManager` what it should
 do with a task
 */
public enum InterceptCommand {
    /**
     Proceed with execution of the task

     - Note: This will cause all held tasks to be executed as well
     */
    case execute

    /// Hold on to this task for now
    case hold

    /// Discard this task (throws it away)
    case discard

    /**
     Ignored hold and execute commands and executes the task

     - Note: This will cause all held tasks to be executed as well
     */
    case forceExecute
}

/**
 A task interceptor allows you to somewhat control what the task manager should do when it encounters a task
 */
public protocol TaskInterceptor {
    /**
     This is called on every task and allows you to tell the task manager how to treat
     this task based on the `InterceptCommand` that you return
     */
    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand
}
