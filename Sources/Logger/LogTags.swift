import Foundation

/**
 Thes log tags can be passed to filter the logs produced by Tasker. This can be used
 to aid in debugging, or to get information about what your tasks are up to.

 SeeAlso:
    - `Logger`
 */
public struct LogTags {
    /// The queue that a task is being handled on
    public static let onTaskQueue = "tq"

    /// The queue that a task is executing on
    public static let onOperationQueue = "oq"

    /// The queue that a reactor is being executed on
    public static let onReactorQueue = "rq"

    /// The caller's thread
    public static let caller = "cq"

    /// The queue that an interceptor is being executed on
    public static let onInterceptorQueue = "iq"
}
