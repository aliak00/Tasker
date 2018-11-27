import Foundation

///
public struct TaskReactorConfiguration {
    let timeout: DispatchTimeInterval?
    let requeuesTask: Bool
    let suspendsTaskQueue: Bool

    ///
    public init(
        timeout: DispatchTimeInterval? = nil,
        requeuesTask: Bool = false,
        suspendsTaskQueue: Bool = false
    ) {
        self.timeout = timeout
        self.requeuesTask = requeuesTask
        self.suspendsTaskQueue = suspendsTaskQueue
    }

    ///
    public static let `default` = TaskReactorConfiguration()
}
