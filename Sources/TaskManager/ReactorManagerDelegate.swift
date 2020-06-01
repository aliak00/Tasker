import Foundation

protocol ReactorManagerDelegate: AnyObject {
    func reactorsCompleted(handlesToRequeue: [TaskManager.Handle: ReactorManager.RequeueData])
    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError)
}
