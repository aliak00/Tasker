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

public class URLInterceptor {

    static var globalStore = SynchronizedDictionary<String, TaskManager>()

    static let key: String = {
        return "com.swooft.URLInterceptor.\(String(UUID().uuidString.prefix(6)))"
    }()

    let taskManager: TaskManager

    public let session: URLSession

    public init(interceptors: [TaskInterceptor], configuration: URLSessionConfiguration) {
        self.taskManager = TaskManager(interceptors: interceptors)

        var copyOfHeaders = configuration.httpAdditionalHeaders ?? [:]
        let ref = String(describing: ObjectIdentifier(self.taskManager).hashValue)
        copyOfHeaders[URLInterceptor.key] = ref
        let copyOfConfig = configuration
        copyOfConfig.httpAdditionalHeaders = copyOfHeaders
        copyOfConfig.protocolClasses = [URLInterceptorProtocol.self]

        self.session = URLSession(configuration: copyOfConfig)

        URLInterceptor.globalStore[ref] = self.taskManager
        log(from: self, "added task manager with global key \(ref)")
    }

    deinit {
        let ref = String(describing: ObjectIdentifier(self.taskManager).hashValue)
        URLInterceptor.globalStore[ref] = nil
        log(from: self, "removed task manager with global key \(ref)")
    }
}
