import Tasker
import XCTest

private class Interceptor: TaskInterceptor {
    func intercept<T>(task: inout T, currentBatchCount _: Int) -> InterceptCommand where T: Task {
        guard let task = task as? URLInterceptor.DataTask else {
            return .execute
        }
        task.request.addValue("hahaha", forHTTPHeaderField: "hahaha")
        return .execute
    }
}

private class Reactor: TaskReactor {
    func execute(done: @escaping (Error?) -> Void) {
        done(nil)
    }

    func shouldExecute<T: Task>(after result: T.Result, from task: T, with _: TaskHandle) -> Bool {
        guard let result = result as? URLInterceptor.DataTask.Result else {
            return false
        }
        if case let .success(tuple) = result {
            return (tuple.1 as? HTTPURLResponse)?.statusCode == 200
        }
        return false
    }

    var configuration: TaskReactorConfiguration {
        return TaskReactorConfiguration(
            isImmediate: true,
            timeout: nil,
            requeuesTask: true,
            suspendsTaskQueue: false
        )
    }
}

extension Data {
    func string() -> String? {
        return String(data: self, encoding: .utf8)
    }
}

// extension XCTest {
//     @discardableResult
//     public func stub(_ matcher: @escaping Mockingjay.Matcher, delay: TimeInterval? = nil, _ builders: [(URLRequest) -> Response]) -> Stub {
//         let max = builders.count
//         var count = 0
//         return self.stub(matcher, delay: delay, { request -> Response in
//             let builder = builders[count]
//             if count < max - 1 {
//                 count += 1
//             }
//             return builder(request)
//         })
//     }
// }

final class URLInterceptorTests: XCTestCase {
    func testShould() {
        //     func matcher(request: URLRequest) -> Bool {
        //         return request.allHTTPHeaderFields?["hahaha"] == "hahaha"
        //     }
        //     self.stub(matcher, [
        //         jsonData("yodles".data(using: .utf8)!),
        //         http(400),
        //     ])

        //     let urlInterceptor = URLInterceptor(interceptors: [Interceptor()], reactors: [Reactor()], configuration: .default)
        //     let task = urlInterceptor.session.dataTask(with: URL(string: "http://www.msftncsi.com/ncsi.txt")!) { data, response, error in
        //         print("# 1", data!.string()!)
        //         print("# 2", response as Any)
        //         print("# 3", error as Any)
        //     }
        //     task.resume()
        //     // task.cancel()

        //     ensure(task.state.rawValue).becomes(URLSessionTask.State.completed.rawValue)
    }
}