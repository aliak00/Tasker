import Foundation

/**
 This is URLSession wrapper that also keeps track of a `TaskManager` so that you can deploy `TaskInterceptor`s and
 `TaskReactor`s on the URLSession tasks. The ideas behind this URLInterceptor is to be able to control the URLSession
 tasks at a more fine grained level, and to have a automatic mechanism to re-fire them should the need arise.

 This is done by setting a URLProtocol on the URLSession object that is exposed to the client. Therefore, the
 URLSessionConfiguration object that you pass in to the URLInterceptor object will have its `protocolClasses`
 member changed.

 One example of a use case is to be able to do OAuth2 refresh operations. Should a task come back with an 401 status
 code, a reactor can perform a refresh operation, reset the any user state to include the new authorization and
 refresh token, and the requeue the task.

 ## Intercepting tasks

 When you write a `TaskInterceptor` the object that needs to be intercepted must conform to the `Task` protocol.
 For this reason, the URLInterceptor module has a `URLInterceptorTask` type. That is the `Task` object that
 will be passed in to the `TaskInterceptor.intercept(...)` function.

 ```
 class Interceptor: TaskInterceptor {
   let user: User
   init(user: User) {
     self.user = user
   }
   func intercept<T>(task: inout T, currentBatchCount _: Int) -> InterceptCommand where T: Task {
     // Cast to the concrete type
     guard let task = task as? URLInterceptorTask else {
       return .execute
     }
     // Add a field to the request before it's fired off
     task.request.addValue(self.user.authorization, forHTTPHeaderField: "Authorization")
     return .execute
   }
 }
 ```

 ## Reacting to tasks

 The same principles apply as with intercepting tasks. To react to a task first cast the `Task` object
 to a `URLInterceptorTask` object and you will have access to the actual `URLRequest` object that was
 used to make the original request.

 ```
 class Reactor: TaskReactor {
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

   func shouldExecute<T: Task>(after result: T.Result, from task: T, with _: TaskHandle) -> Bool {
     guard let result = result as? URLInterceptorTask.Result else {
       return false
     }
     // One can return true if there's a 401 UNAUTHORIZED http response code.
     if case let .success(value) = result {
       return value.(response as? HTTPURLResponse)?.statusCode == 401
     }
     return false
   }
 }
 ```

 */
public class URLInterceptor {
    static var globalTaskManagers = SynchronizedDictionary<String, TaskManager>()

    static let key: String = {
        "Tasker.URLInterceptor.\(String(UUID().uuidString.prefix(6)))"
    }()

    let taskManager: TaskManager

    /// And tasks executed through this URLSession can be intercetped and reacted to.
    public let session: URLSession

    /**
     Creates a URLInterceptor object

     - parameter interceptors: list of interceptors that will be run before each URLSessionTask is executed
     - parameter rectors: list of reactors that will run upon completion of the URLSessionTask
     - parameter configuration: passed on to the URLSession object
     */
    public init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = [], configuration: URLSessionConfiguration) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
        self.session = URLSession(configuration: configuration.copy(for: URLInterceptorProtocol.self, manager: self.taskManager))
        // Set up the global store to hold a reference to the TaskManager that will be used to handle the
        // interceptor and reactors.
        URLInterceptor.globalTaskManagers[self.taskManager.refKey] = self.taskManager
        log(from: self, "added task manager with global key \(self.taskManager.refKey)")
    }

    deinit {
        URLInterceptor.globalTaskManagers[self.taskManager.refKey] = nil
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
        copyOfHeaders[URLInterceptor.key] = manager.refKey
        let copyOfConfig = self
        copyOfConfig.httpAdditionalHeaders = copyOfHeaders
        copyOfConfig.protocolClasses = [type]
        return copyOfConfig
    }
}
