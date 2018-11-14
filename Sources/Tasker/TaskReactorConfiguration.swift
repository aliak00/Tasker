import Foundation

public struct TaskReactorConfiguration {
    let isImmediate: Bool
    let timeout: DispatchTimeInterval?
    let requeuesTask: Bool
    let suspendsTaskQueue: Bool

    public init(
        isImmediate: Bool = false,
        timeout: DispatchTimeInterval? = nil,
        requeuesTask: Bool = false,
        suspendsTaskQueue: Bool = false
    ) {
        self.isImmediate = isImmediate
        self.timeout = timeout
        self.requeuesTask = requeuesTask
        self.suspendsTaskQueue = suspendsTaskQueue
    }

    public static let `default` = TaskReactorConfiguration()
}
