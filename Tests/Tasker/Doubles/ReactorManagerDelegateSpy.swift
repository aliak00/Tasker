@testable import Tasker

class ReactorManagerDelegateSpy: ReactorManagerDelegate {

    var reactorsCompletedData: SynchronizedArray<[TaskManager.Handle: ReactorManager.RequeueData]> = []

    func reactorsCompleted(handlesToRequeue: [TaskManager.Handle: ReactorManager.RequeueData]) {
        self.reactorsCompletedData.append(handlesToRequeue)
    }

    typealias ReactorFailedData = (associatedHandles: Set<TaskManager.Handle>, error: TaskError)

    var reactorFailedData: SynchronizedArray<ReactorFailedData> = []

    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError) {
        self.reactorFailedData.append(ReactorFailedData(associatedHandles, error))
    }
}
