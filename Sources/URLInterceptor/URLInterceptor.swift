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

private extension TaskManager {
    var refKey: String {
        return String(describing: ObjectIdentifier(self).hashValue)
    }
}

private extension URLSessionConfiguration {
    func copy(for type: URLProtocol.Type, manager: TaskManager) -> URLSessionConfiguration {
        var copyOfHeaders = self.httpAdditionalHeaders ?? [:]
        copyOfHeaders[URLInterceptor.key] = manager.refKey
        let copyOfConfig = self
        copyOfConfig.httpAdditionalHeaders = copyOfHeaders
        copyOfConfig.protocolClasses = [type]
        return copyOfConfig
    }
}

public class URLInterceptor {

    static var globalStore = SynchronizedDictionary<String, TaskManager>()

    static let key: String = {
        "Swooft.URLInterceptor.\(String(UUID().uuidString.prefix(6)))"
    }()

    let taskManager: TaskManager

    public let session: URLSession

    public init(interceptors: [TaskInterceptor] = [], reactors: [TaskReactor] = [], configuration: URLSessionConfiguration) {
        self.taskManager = TaskManager(interceptors: interceptors, reactors: reactors)
        self.session = URLSession(configuration: configuration.copy(for: URLInterceptorProtocol.self, manager: self.taskManager))
        URLInterceptor.globalStore[self.taskManager.refKey] = self.taskManager
        log(from: self, "added task manager with global key \(self.taskManager.refKey)")
    }

    deinit {
        URLInterceptor.globalStore[self.taskManager.refKey] = nil
        log(from: self, "removed task manager with global key \(self.taskManager.refKey)")
    }
}
