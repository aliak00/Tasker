/*
 Copyright 2017 Ali Akhtarzada

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation

extension URLInterceptor {
    public class DataTask: Task {
        public var request: URLRequest

        var task: URLSessionDataTask?

        init(_ request: URLRequest) {
            self.request = request
        }

        public typealias SuccessValue = (data: Data?, response: URLResponse?, error: Error?)

        public func execute(completionHandler: @escaping (Result<(data: Data?, response: URLResponse?, error: Error?)>) -> Void) {

            print("sending", self.request.allHTTPHeaderFields)

            self.task = URLSession.shared.dataTask(with: self.request) { data, response, error in
                let value: SuccessValue = (data, response, error)
                print(data as Any)
                print(response as Any)
                print(error as Any)
                completionHandler(.success(value))
            }

            self.task?.resume()
        }

        public func didCancel(with _: TaskError) {
            self.task?.cancel()
        }
    }
}
