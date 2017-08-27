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
    private var allowedTags = Set<String>()
    private var ignoredTags = Set<String>()
    private var filePathMemo: [String: String] = [:]
    private var historyBuffer: RingBuffer<String>?

    public var printTags = false

    public init() {
        self.historyBuffer = nil
    }

    public init(logHistorySize _: Int) {
        self.historyBuffer = RingBuffer(size: 50)
    }

    public func addTransport(_ transport: @escaping (String) -> Void) {
        self.transports.append(transport)
    }

    public func filterUnless(tag: String) {
        self.allowedTags.insert(tag)
    }

    public func filterUnless(tags: [String]) {
        self.allowedTags = self.allowedTags.union(tags)
    }

    public func filterIf(tag: String) {
        self.ignoredTags.insert(tag)
    }

    public func filterIf(tags: [String]) {
        self.ignoredTags = self.ignoredTags.union(tags)
    }

    public func log<T>(_ object: @autoclosure () -> T, tag: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        self.log(object(), tags: [tag], file, function, line)
    }

    public func log<T>(_ object: @autoclosure () -> T, tags: [String] = [], _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard self.transports.count > 0 else {
            return
        }

        let string = "\(object())"

        if self.ignoredTags.count > 0 && self.ignoredTags.intersection(tags).count > 0 {
            return
        }

        if self.allowedTags.count > 0 && self.allowedTags.intersection(tags).count == 0 {
            return
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

        var tagsString = ""
        if tags.count > 0 && self.printTags {
            tagsString = ":\(tags.joined(separator: ","))"
        }
        let output = "[\(queue)-\(tid):\(fileName):\(line):\(functionName)\(tagsString)] => \(string)"
        self.historyBuffer?.append(output)
        for transport in self.transports {
            transport(output)
        }
    }
}
