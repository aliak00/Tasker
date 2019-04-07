import Foundation

class URLInterceptorProtocol: URLProtocol {
    // This is a hack that's used to lookup a TaskManager associated with a URLSession object
    static let key: String = {
        String(UUID().uuidString.prefix(6))
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        // Check if the URLRequest that comes in here is one that is actually ours. This means that
        // there will be a key set in the additional http headers, because that's what we do when
        // we create a URLInterceptor object.
        guard let taskManagerKey = request.allHTTPHeaderFields?[URLInterceptor.key] else {
            log(from: self, "URLInterceptor key \(URLInterceptor.key) not found in request \(request)")
            return false
        }
        // Make sure we still have a reference to the actual TaskManager object
        guard URLInterceptor.globalTaskManagers[taskManagerKey] != nil else {
            log(from: self, "TaskManager key \(taskManagerKey) not found in request \(request)")
            return false
        }
        log(from: self, "will proceed with \(request)")
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    private func normalizeRequest(_ request: URLRequest) -> URLRequest {
        // Since we artificially add an http header, we need to remove it before
        // we send off the actual request.
        var normalizedRequest = request
        normalizedRequest.setValue(nil, forHTTPHeaderField: URLInterceptor.key)
        return normalizedRequest
    }

    weak var handle: TaskHandle?

    override func startLoading() {

        log(from: self, "starting \(self.request)")

        // Get a hold of out taskManager
        guard let key = request.allHTTPHeaderFields?[URLInterceptor.key], let taskManager = URLInterceptor.globalTaskManagers[key] else {
            self.client?.urlProtocol(self, didFailWithError: URLInterceptorError.keyNotFound)
            return
        }

        // Create a URLIntercetor task and fire it off
        let task = URLInterceptorTask(self.normalizeRequest(request))
        self.handle = taskManager.add(task: task) { [weak self] result in
            guard let strongSelf = self else { return }
            do {
                let tuple = try result.get()
                if let response = tuple.response {
                    strongSelf.client?.urlProtocol(strongSelf, didReceive: response, cacheStoragePolicy: .allowed)
                }
                if let data = tuple.data {
                    strongSelf.client?.urlProtocol(strongSelf, didLoad: data)
                }
                if let error = tuple.error {
                    throw error
                }
                strongSelf.client?.urlProtocolDidFinishLoading(strongSelf)
            } catch {
                strongSelf.client?.urlProtocol(strongSelf, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        log(from: self, "stopping \(self.request)")
        self.handle?.cancel()
    }
}
