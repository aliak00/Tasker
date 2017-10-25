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

/**
 A logging class that can be told where to log to. A lot of different components within
 Swooft use the shared logger to output log information.

 The logger optionally keeps a history of recent logs in memory if you tell it to during
 construction.

 ## Filtering

 Two methods exist to allow for filtering of the log stream.

 - `Logger.filterUnless(tag:)`
 - `Logger.filterIf(tag:)`

 ## Performance

 Each log call is given the current line, file and func that the message is
 logged from. The file is file path is out in to a `URL` object and the
 extension removed. This is optionally memoized inside a cache object to avoid
 the operation on each log call.
 */
public class Logger {
    /// Shared logger object
    public static let shared = Logger()

    private var transports: [(String) -> Void] = []
    private var allowedTags = Set<String>()
    private var ignoredTags = Set<String>()
    private var filePathMemo: Cache<String, String>?
    private var historyBuffer: RingBuffer<String>?

    /// Set to true if you want the tags to be printed as well
    public var outputTags = false

    /// If this is true then it ignores all logs
    public var enabled = true

    /**
     Initializes a Logger object

     - parameter logHistorySize: How many entried to keep in the history
     - parameter fileLookupMemoCapacity: How big you want the file lookup cache to be
     */
    public init(logHistorySize: Int? = nil, fileLookupMemoCapacity: Int? = 100) {
        if let logHistorySize = logHistorySize {
            self.historyBuffer = RingBuffer(capacity: logHistorySize)
        } else {
            self.historyBuffer = nil
        }
        if let fileLookupMemoCapacity = fileLookupMemoCapacity {
            self.filePathMemo = Cache(capacity: fileLookupMemoCapacity)
        } else {
            self.filePathMemo = nil
        }
    }

    /**
     Adding a transport allows you to tell the logger where the output goes to. You may add as
     many as you like.

     - parameter transport: function that is called with each log invocaton
     */
    public func addTransport(_ transport: @escaping (String) -> Void) {
        self.transports.append(transport)
    }

    /// Filters log messages unless they are tagged with `tag`
    public func filterUnless(tag: String) {
        self.allowedTags.insert(tag)
    }

    /// Filters log messages unless they are tagged with any of `tags`
    public func filterUnless(tags: [String]) {
        self.allowedTags = self.allowedTags.union(tags)
    }

    /// Filters log messages if they are tagged with `tag`
    public func filterIf(tag: String) {
        self.ignoredTags.insert(tag)
    }

    /// Filters log messages if they are tagged with any of `tags`
    public func filterIf(tags: [String]) {
        self.ignoredTags = self.ignoredTags.union(tags)
    }

    /**
     Logs any `T` by using string interpolation

     - parameter object: autoclosure statment to be logged
     - parameter tag: a tag to apply to this log
     */
    public func log<T>(_ object: @autoclosure () -> T, tag: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        self.log(object(), tags: [tag], file, function, line)
    }

    /**
     Logs any `T` by using string interpolation

     - parameter object: autoclosure statment to be logged
     - parameter tags: a set of tags to apply to this log
     */
    public func log<T>(_ object: @autoclosure () -> T, tags userTags: [String] = [], _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        guard self.transports.count > 0 else {
            return
        }

        let functionName = function.components(separatedBy: "(").first ?? ""
        let thread = Thread.isMainThread ? "UI" : "BG"

        let fileName: String = {
            if let name = self.filePathMemo?[file] {
                return name
            }
            let name = URL(fileURLWithPath: file)
                .deletingPathExtension().lastPathComponent
            let value = name.isEmpty ? "Unknown file" : name
            self.filePathMemo?[file] = value
            return value
        }()

        var allTags = [functionName, thread, fileName]
        allTags.append(contentsOf: userTags)

        if self.ignoredTags.count > 0 && self.ignoredTags.intersection(allTags).count > 0 {
            return
        }

        if self.allowedTags.count > 0 && self.allowedTags.intersection(allTags).count == 0 {
            return
        }

        let tid = pthread_mach_thread_np(pthread_self())
        let string = "\(object())"

        var tagsString = ""
        if userTags.count > 0 && self.outputTags {
            tagsString = ":\(userTags.joined(separator: ","))"
        }
        let output = "[\(thread)-\(tid):\(fileName):\(line):\(functionName)\(tagsString)] => \(string)"
        self.historyBuffer?.append(output)
        for transport in self.transports {
            transport(output)
        }
    }
}
