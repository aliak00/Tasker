import Foundation

protocol ReactorManagerDelegate: AnyObject {
    func reactorsCompleted(handlesToRequeue: Set<TaskManager.Handle>)
    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError)
}
