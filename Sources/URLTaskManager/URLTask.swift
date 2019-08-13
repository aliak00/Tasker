import Foundation

/**
 This is the `Task` object that is used by `URLTaskManager`. This is the type of the `Task` object
 that would be passed in to `URLTaskInterceptor.intercept(...)` and `URLTaskReactor.shouldExecute(...)`
 when using the `URLTaskManager`.
 */
public class URLTask: Task {
    /// The URLRequest object that was used to make the original request with `URLTaskManager.session`
    public var request: URLRequest

    var task: URLSessionDataTask?

    init(_ request: URLRequest) {
        self.request = request
    }

    /// It's the tuple that's returned by called methods on URLSession
    public typealias SuccessValue = (data: Data?, response: URLResponse?, error: Error?)

    /// Executes the URLRequest
    public func execute(completion: @escaping CompletionCallback) {
        self.task = URLSession.shared.dataTask(with: self.request) { data, response, error in
            let value: SuccessValue = (data, response, error)
            completion(.success(value))
        }

        self.task?.resume()
    }

    /// Calls URLSessionTask.cancel
    public func didCancel(with _: TaskError) {
        self.task?.cancel()
    }
}
