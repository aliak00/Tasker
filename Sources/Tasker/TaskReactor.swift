import Foundation

/**
 A task reactor allows you to control what the task manager should do after a task is completed,
 and before the completion callback is called.

 ## Multiple reactors

 If a there're multiple reactors that are supposed to be run for a task then the options set in the
 `TaskReactorConfiguration` are OR'ed together to determine what to do with the task. I.e. if one reactor
 of `n` reactors is configured to reqeue a task, then the task will be requeued.
 */
public protocol TaskReactor {
    /**
     Return true if you want this reactor to be executed

     - parameter after: the result of the task that was just executed
     - parameter from: the actual task that was just executed
     - parameter with: the handle to the task that was just executed
     */
    func shouldExecute<T: Task>(after: T.Result, from: T, with: TaskHandle) -> Bool

    /**
     Does the interceptor work
     */
    func execute(done: @escaping (Error?) -> Void)

    /**
     The configuration that this interceptor has
     */
    var configuration: TaskReactorConfiguration { get }
}

extension TaskReactor {
    func execute(done: @escaping (Error?) -> Void) {
        done(nil)
    }

    func shouldExecute<T: Task>(after _: T.Result, from _: T, with _: TaskHandle) -> Bool {
        return false
    }

    var configuration: TaskReactorConfiguration {
        return .default
    }
}
