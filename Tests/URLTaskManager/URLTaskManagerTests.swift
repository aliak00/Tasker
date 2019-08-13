import Tasker
import XCTest

private class Interceptor: URLTaskInterceptor {
    func intercept(task: inout URLTask, currentBatchCount _: Int) -> InterceptCommand {
        task.request.addValue("hahaha", forHTTPHeaderField: "hahaha")
        return .execute
    }
}

private class Reactor: URLTaskReactor {
    var count = 1
    func execute(done: @escaping (Error?) -> Void) {
        done(nil)
    }

    func shouldExecute(after result: URLTask.Result, from task: URLTask, with _: TaskHandle) -> Bool {
        if case .success = result {
            let run = count == 0
            count -= 1
            return run // (tuple.1 as? HTTPURLResponse)?.statusCode == 200
        }
        return false
    }

    var configuration: TaskReactorConfiguration {
        return TaskReactorConfiguration(
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
//        Logger.shared.addTransport { print($0) }
//        func matcher(request: URLRequest) -> Bool {
//            return request.allHTTPHeaderFields?["hahaha"] == "hahaha"
//        }
//        self.stub(matcher, [
//            jsonData("yodles".data(using: .utf8)!),
//            http(400),
//        ])

        let urlTaskManager = URLTaskManager(interceptors: [Interceptor()], reactors: [Reactor()], configuration: .default)
        let task = urlTaskManager.session.dataTask(with: URL(string: "http://www.msftncsi.com/ncsi.txt")!) { data, response, error in
            XCTAssertEqual(data!.string()!, "Microsoft NCSI")
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            XCTAssertNil(error)
        }
        task.resume()
//        task.cancel()

        ensure(task.state.rawValue).becomes(URLSessionTask.State.completed.rawValue)
//        Logger.shared.removeTransports()
    }
}
