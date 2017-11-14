//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Quick
import Nimble

@testable import Swooft

private class Interceptor: TaskInterceptor {
    func intercept<T>(task: inout T, currentBatchCount _: Int) -> InterceptCommand where T: Task {
        guard let task = task as? URLInterceptor.DataTask else {
            return .execute
        }
        task.request.addValue("hahaha", forHTTPHeaderField: "hahaha")
        return .execute
    }
}

class URLInterceptorTests: QuickSpec {

    override func spec() {

        describe("test") {
            it("should") {
                let urlInterceptor = URLInterceptor(interceptors: [Interceptor()], configuration: URLSessionConfiguration.default)
                let task = urlInterceptor.session.dataTask(with: URL(string: "http://www.example.com")!) { data, response, error in
                    print("# 1", data as Any)
                    print("# 2", response as Any)
                    print("# 3", error as Any)
                }
                task.resume()
                task.cancel()

                ensure(task.state.rawValue).becomes(URLSessionTask.State.completed.rawValue)
            }
        }
    }
}
