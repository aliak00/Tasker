import Foundation

/**
 This is URLSession wrapper that provides interception and reaction funcitonality. The ideas behind the
 URLTaskManager is to be able to control URLSession tasks at a more fine grained level, and to have a
 automatic mechanism to re-fire them should the need arise.

 This is done by setting a URLProtocol on the URLSession object that is exposed to the client. Therefore, the
 URLSessionConfiguration object that you pass in to the URLTaskManager object will have its `protocolClasses`
 member changed.

 One example of a use case is to be able to do OAuth2 refresh operations. Should a task come back with a 401 status
 code, a reactor can perform a refresh operation, reset the any user state to include the new authorization and
 refresh token, and the requeue the task.

 Another use case if you want to enrich a URL tasks with headers, or if you want to batch url requests and release
 them in one go.

 ## Intercepting tasks

 Every request that is sent through `URLTaskManager.session` is run through any associated `URLTaskInterceor`s or
 `URLTaskReactor`s as a `URLTask` object that contain an accessible `URLRequest` object.

 ```
 class Interceptor: URLTaskInterceptor {
   let user: User
   init(user: User) {
     self.user = user
   }
   func intercept(task: inout URLTask, currentBatchCount _: Int) -> InterceptCommand {
     // Add a field to the request before it's fired off
     task.request.addValue(self.user.authorization, forHTTPHeaderField: "Authorization")
     return .execute
   }
 }
 ```

 ## Reacting to tasks

 The same principles apply as with intercepting tasks. To react to a a `URLTask` object you may
 implement a `URLTaskReactor` object.

 ```
 class Reactor: URLTaskReactor {
   let user: User
   init(user: User) {
     self.user = user
   }

   func execute(done: @escaping (Error?) -> Void) {
     // For example one could refresh the authorization tokens here
     user.refreshAuthorizationToken { result in
       switch result {
       case .success:
         done(nil)
       case let .failure(value):
         done(value)
     }
   }

   func shouldExecute<T: Task>(after result: URLTask.Result, from task: URLTask, with _: Handle) -> Bool {
     if case let .success(value) = result {
       return value.(response as? HTTPURLResponse)?.statusCode == 401
     }
     return false
   }
 }
 ```

 */
public class URLTaskManager {
    /**
     This keeps track of the task managers and which url task manager owns them. The trick here is
     that whenever you create a `URLTaskManager` with a `URLSessionConfiguration` object, a special
     key that looks up in to this dictionary is injected in to the additional headers of the
     `URLSession`. These headers are removed before making the request
     */
    static var globalTaskManagers = SynchronizedDictionary<String, TaskManager>()
    static let key: String = {
        "Tasker.URLTaskManager.\(String(UUID().uuidString.prefix(6)))"
    }()

    let taskManager: TaskManager

    /// And tasks executed through this URLSession can be intercetped and reacted to.
    public let session: URLSession

    /**
     Creates a URLTaskManager object

     - parameter interceptors: list of interceptors that will be run before each URLSessionTask is executed
     - parameter rectors: list of reactors that will run upon completion of the URLSessionTask
     - parameter configuration: passed on to the URLSession object
     */
    public init(interceptors: [URLTaskInterceptor] = [], reactors: [URLTaskReactor] = [], configuration: URLSessionConfiguration = .default) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
        self.session = URLSession(configuration: configuration.copy(for: URLTaskManagerProtocol.self, manager: self.taskManager))
        // Set up the global store to hold a reference to the TaskManager that will be used to handle the
        // interceptor and reactors.
        URLTaskManager.globalTaskManagers[self.taskManager.refKey] = self.taskManager
        log(from: self, "added task manager with global key \(self.taskManager.refKey)")
    }

    deinit {
        URLTaskManager.globalTaskManagers[self.taskManager.refKey] = nil
        log(from: self, "removed task manager with global key \(self.taskManager.refKey)")
    }
}

private extension TaskManager {
    var refKey: String {
        return String(describing: ObjectIdentifier(self).hashValue)
    }
}

private extension URLSessionConfiguration {
    func copy(for type: URLProtocol.Type, manager: TaskManager) -> URLSessionConfiguration {
        var copyOfHeaders = self.httpAdditionalHeaders ?? [:]
        // Store the reference to this manager object in the global http headers that will be
        // associated with every request that goes through this URLSession object. This is
        // later used to lookup the actual instance of the manager from the globalTaskManagers
        copyOfHeaders[URLTaskManager.key] = manager.refKey
        let copyOfConfig = self
        copyOfConfig.httpAdditionalHeaders = copyOfHeaders
        copyOfConfig.protocolClasses = [type]
        return copyOfConfig
    }
}
