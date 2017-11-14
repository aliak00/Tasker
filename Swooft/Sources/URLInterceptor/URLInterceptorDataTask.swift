//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Foundation

extension URLInterceptor {
    public class DataTask: Task {
        public var request: URLRequest

        var task: URLSessionDataTask?

        init(_ request: URLRequest) {
            self.request = request
        }

        public typealias SuccessValue = (data: Data?, response: URLResponse?, error: Error?)

        public func execute(completion: @escaping (Result<(data: Data?, response: URLResponse?, error: Error?)>) -> Void) {
            self.task = URLSession.shared.dataTask(with: self.request) { data, response, error in
                let value: SuccessValue = (data, response, error)
                completion(.success(value))
            }

            self.task?.resume()
        }

        public func didCancel(with _: TaskError) {
            self.task?.cancel()
        }
    }
}
