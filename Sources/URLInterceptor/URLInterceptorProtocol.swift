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

class URLInterceptorProtocol: URLProtocol {
    static let key: String = {
        String(UUID().uuidString.prefix(6))
    }()

    override class func canInit(with request: URLRequest) -> Bool {
        guard let taskManagerKey = request.allHTTPHeaderFields?[URLInterceptor.key] else {
            log(from: self, "URLInterceptor key \(URLInterceptor.key) not found in request \(request)")
            return false
        }
        guard URLInterceptor.globalStore[taskManagerKey] != nil else {
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
        var normalizedRequest = request
        normalizedRequest.setValue(nil, forHTTPHeaderField: URLInterceptor.key)
        return normalizedRequest
    }

    weak var handle: TaskHandle?

    override func startLoading() {
        log(from: self, "starting \(self.request)")
        guard let key = request.allHTTPHeaderFields?[URLInterceptor.key], let taskManager = URLInterceptor.globalStore[key] else {
            self.client?.urlProtocol(self, didFailWithError: GenericError.CannotComply())
            return
        }
        let task = URLInterceptor.DataTask(self.normalizeRequest(request))
        self.handle = taskManager.add(task: task) { [weak self, weak task] result in
            guard let strongSelf = self else { return }
            do {
                let tuple = try result.materialize()
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
                if case TaskError.cancelled = error {
                    task?.task?.cancel()
                }
                strongSelf.client?.urlProtocol(strongSelf, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        log(from: self, "stopping \(self.request)")
        self.handle?.cancel()
    }
}
