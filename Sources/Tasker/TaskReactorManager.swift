import Foundation

protocol TaskReactorManagerDelegate: class {
    func reactorsCompleted(handlesToRequeue: Set<TaskManager.Handle>)
    func reactorFailed(associatedHandles: Set<TaskManager.Handle>, error: TaskError)
}

class TaskReactorManager {
    private static let kTags = [LogTags.onReactorQueue]
    private let queue = DispatchQueue(label: "Tasker.TaskReactorManager")

    weak var delegate: TaskReactorManagerDelegate?
    let reactors: [TaskReactor]

    private var executingReactors = Set<Int>()
    private var handlesToRequeue = Set<TaskManager.Handle>() // TODO: Can/should these handles be weak?
    private var assoiciatedHandles: [Int: Set<TaskManager.Handle>] = [:] // TODO: Can/should these handles be weak?
    
    init(reactors: [TaskReactor]) {
        self.reactors = reactors
        for index in 0..<reactors.count {
            self.assoiciatedHandles[index] = Set<TaskManager.Handle>()
        }
    }

    struct ReactionResult : Equatable {
        let requeueTask: Bool
        let suspendQueue: Bool
    }

    func react<T: Task>(task: T, result: T.Result, handle: TaskManager.Handle, completion: @escaping (ReactionResult) -> Void) {
        // Complete immediately if there're no reactors
        guard !self.reactors.isEmpty else {
            completion(ReactionResult(requeueTask: false, suspendQueue: false))
            return
        }

        self.queue.async {
            let reactionData = self
                .reactors
                .enumerated()
                .reduce((indicesToRun: [Int](), requeueTask: false, suspendQueue: false)) { memo, pair in
                    let index = pair.offset
                    let reactor = pair.element
                    var indices = memo.indicesToRun
                    var requeueTask = memo.requeueTask
                    var suspendQueue = memo.suspendQueue
                    if reactor.shouldExecute(after: result, from: task, with: handle) {
                        indices.append(index)
                        // If any of the reactors say we need to requeue, then we need to requeue
                        requeueTask = memo.requeueTask || reactor.configuration.requeuesTask

                        // If any of the reactors say we need to suspend, then we need to suspend
                        suspendQueue = memo.suspendQueue || reactor.configuration.suspendsTaskQueue
                    }
                    return (indices, requeueTask, suspendQueue)
            }

            log(level: .verbose, from: self, "\(handle) reaction result is \(reactionData)")

            if reactionData.requeueTask {
                log(from: self, "saving \(handle) to requeue list", tag: LogTags.onReactorQueue)
                self.handlesToRequeue.insert(handle)

                // Associate this handle with the reactors that will be triggered
                for index in reactionData.indicesToRun {
                    self.assoiciatedHandles[index]?.insert(handle)
                }
            }

            self.launchReactors(indices: reactionData.indicesToRun)

            completion(
                ReactionResult(requeueTask: reactionData.requeueTask, suspendQueue: reactionData.suspendQueue)
            )
        }
    }

    func launchReactors(indices reactorIndices: [Int]) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
            __dispatch_assert_queue(self.queue)
            #endif
        }

        // No need to run reactors that are already executing
        let nonExecutingReactors = Set(reactorIndices).subtracting(self.executingReactors)
        guard nonExecutingReactors.count > 0 else {
            log(from: self, "already executing \(self.executingReactors)", tag: LogTags.onReactorQueue)
            return
        }

        for index in nonExecutingReactors {
            let reactor = self.reactors[index]
            self.executingReactors.insert(index)

            var timeoutWorkItem: DispatchWorkItem?
            var reactorWorkItem: DispatchWorkItem!

            reactorWorkItem = DispatchWorkItem { [weak self] in
                guard let strongSelf = self else {
                    log(level: .verbose, from: self, "reactor manager dead", tag: LogTags.onReactorQueue)
                    return
                }

                log(from: strongSelf, "will execute reactor \(index): \(reactor.self)", tag: LogTags.onReactorQueue)

                reactor.execute { maybeError in
                    // Get back on reactor queue incase reactor.execute left that queue
                    self?.queue.async {
                        if reactorWorkItem.isCancelled {
                            log(level: .verbose, from: self, "reactor \(index) cancelled", tag: LogTags.onReactorQueue)
                            return
                        }

                        guard let strongSelf = self else {
                            log(level: .verbose, from: self, "reactor manager dead", tag: LogTags.onReactorQueue)
                            return
                        }

                        timeoutWorkItem?.cancel()

                        log(from: self, "did execute reactor \(index)", tag: LogTags.onReactorQueue)

                        if let error = maybeError {
                            strongSelf.cancelAssociatedTasksForReactor(at: index, with: .reactorFailed(type: type(of: reactor), error: error))
                        }

                        strongSelf.removeExecutingReactor(at: index)
                    }
                }
            }

            self.queue.async(execute: reactorWorkItem)

            // Give the async interceptor operation a timeout to complete
            if let timeout = reactor.configuration.timeout {
                timeoutWorkItem = DispatchWorkItem { [weak self] in
                    if timeoutWorkItem!.isCancelled {
                        log(from: self, "reactor \(index) timeout work cancelled", tag: LogTags.onReactorQueue)
                        return
                    }

                    guard let strongSelf = self else {
                        log(level: .verbose, from: self, "reactor manager dead", tag: LogTags.onReactorQueue)
                        return
                    }

                    reactorWorkItem.cancel()

                    log(from: self, "reactor \(index) timed out", tag: LogTags.onReactorQueue)

                    strongSelf.cancelAssociatedTasksForReactor(at: index, with: .reactorTimedOut(type: type(of: reactor)))
                    strongSelf.removeExecutingReactor(at: index)

                }
                self.queue.asyncAfter(deadline: .now() + timeout, execute: timeoutWorkItem!)
            }
        }
    }

    private func removeExecutingReactor(at index: Int) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
            __dispatch_assert_queue(self.queue)
            #endif
        }
        self.executingReactors.remove(index)
        log(from: self, "removed reactor \(index)", tag: LogTags.onReactorQueue)
        if self.executingReactors.count == 0 {
            let data = self.handlesToRequeue
            log(level: .debug, "reactions completed, retrieved \(data.count) requeue handles")
            self.delegate?.reactorsCompleted(handlesToRequeue: data)
            self.handlesToRequeue = Set<TaskManager.Handle>()
        }
    }

    private func cancelAssociatedTasksForReactor(at index: Int, with error: TaskError) {
        if #available(iOS 10.0, OSX 10.12, *) {
            #if !os(Linux)
            __dispatch_assert_queue(self.queue)
            #endif
        }

        let data = self.assoiciatedHandles[index] ?? Set<TaskManager.Handle>()
        for handle in data {
            if self.handlesToRequeue.remove(handle) != nil {
                log(from: self, "removed \(handle) from requeue list", tag: LogTags.onReactorQueue)
            }
        }
        self.delegate?.reactorFailed(associatedHandles: data, error: error)
        self.assoiciatedHandles[index]?.removeAll()
    }
}
