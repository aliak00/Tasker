import Foundation

/**
 A command that can be returned by a `TaskInterceptor` intercept call that tells a `TaskManager` what it should
 do with a task before executing it.
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
 A task interceptor allows you to somewhat control what the task manager should do when it encounters a task.
 The intercept function will be called before the task is executing. This allows you to control the state of the
 task based on state that you may be interested in.

 ## Interception commands

 After the intercept function is executed, there're a number of commands that can be given to the task manager to
 tell it what to do with the task. The intercept function also contains a current batch count, which tells you how
 many tasks are being held on to by _this_ interceptor.

 - SeeAlso: `InterceptCommand`
 */
public protocol TaskInterceptor {
    /**
     This is called on every task and allows you to tell the task manager how to treat
     this task based on the `InterceptCommand` that you return
     */
    func intercept<T: Task>(task: inout T, currentBatchCount: Int) -> InterceptCommand
}
