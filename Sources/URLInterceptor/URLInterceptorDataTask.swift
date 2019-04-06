import Foundation

extension URLInterceptor {
    ///
    public class DataTask: Task {
        public var request: URLRequest

        var task: URLSessionDataTask?

        init(_ request: URLRequest) {
            self.request = request
        }

        ///
        public typealias SuccessValue = (data: Data?, response: URLResponse?, error: Error?)

        ///
        public func execute(completion: @escaping CompletionCallback) {
            self.task = URLSession.shared.dataTask(with: self.request) { data, response, error in
                let value: SuccessValue = (data, response, error)
                completion(.success(value))
            }

            self.task?.resume()
        }

        ///
        public func didCancel(with _: TaskError) {
            self.task?.cancel()
        }
    }
}
