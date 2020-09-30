struct TaskContext {
    weak var handle: Handle?
    weak var manager: TaskManager?
}

protocol HasTaskContext {
    var taskContext: TaskContext? { get set }
}
