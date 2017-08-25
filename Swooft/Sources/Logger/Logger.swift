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

public class Logger {
    public static let shared = Logger()

    private var transports: [(String) -> Void] = []
    private var tagFilters = Set<String>()

    private let printTags = false
    private var filePathMemo: [String: String] = [:]

    init() {}

    public func addTransport(_ transport: @escaping (String) -> Void) {
        self.transports.append(transport)
    }

    public func filter(tag: String) {
        self.tagFilters.insert(tag)
    }

    public func filter(tags: [String]) {
        self.tagFilters = self.tagFilters.union(tags)
    }

    public func log<T>(_ object: @autoclosure () -> T, tags: [String] = [], _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard self.transports.count > 0 else {
            return
        }
        let value = object()
        let string: String

        switch value {
        case let value as CustomDebugStringConvertible:
            string = value.debugDescription
        case let value as CustomStringConvertible:
            string = value.description
        default:
            fatalError("log only works for values that conform to CustomDebugStringConvertible or CustomStringConvertible")
        }

        if tags.count > 0 && self.tagFilters.count > 0 {
            guard self.tagFilters.intersection(tags).count > 0 else {
                return
            }
        }

        let fileName: String = {
            if let name = self.filePathMemo[file] {
                return name
            }
            let name = URL(fileURLWithPath: file)
                .deletingPathExtension().lastPathComponent
            let value = name.isEmpty ? "Unknown file" : name
            self.filePathMemo[file] = value
            return value
        }()
        let tid = pthread_mach_thread_np(pthread_self())
        let queue = Thread.isMainThread ? "UI" : "BG"

        let functionName = function.components(separatedBy: "(")[0]
        let unquotedString = string.substring(with: string.index(after: string.startIndex)..<string.index(before: string.endIndex))

        var tagsString = ""
        if tags.count > 0 && self.printTags {
            tagsString = ":\(tags.joined(separator: ","))"
        }
        for transport in self.transports {
            transport("[\(queue)-\(tid):\(fileName):\(line):\(functionName)\(tagsString)] => \(unquotedString)")
        }
    }
}
