@testable import Tasker

class ReactorManagerDelegateSpy: ReactorManagerDelegate {
    typealias ReactorsCompletedData = Set<TaskManager.Handle>

    var reactorsCompletedData: SynchronizedArray<ReactorsCompletedData> = []

    func reactorsCompleted(handlesToRequeue: Set<TaskManager.Handle>) {
        self.reactorsCompletedData.append(ReactorsCompletedData(handlesToRequeue))
    }

    typealias ReactorFailedData = (associatedHandles: Set<TaskManager.Handle>, error: TaskError)

    var reactorFailedData: SynchronizedArray<ReactorFailedData> = []

    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError) {
        self.reactorFailedData.append(ReactorFailedData(associatedHandles, error))
    }
}
