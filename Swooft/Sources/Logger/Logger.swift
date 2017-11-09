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

private extension DispatchTime {
    var elapsed: Double {
        let nanoTime = DispatchTime.now().uptimeNanoseconds - self.uptimeNanoseconds
        return Double(nanoTime) / 1_000_000
    }
}

private struct SynchronizedData {
    var enabled: Bool = false
    var outputTags: Bool = false
    var transports: [(String) -> Void] = []
    var allowedTags = Set<String>()
    var ignoredTags = Set<String>()
    var historyBuffer: RingBuffer<String>? = nil
}

/**
 A logging class that can be told where to log to via transports.

 Features include:
 - Asynchronous, ordered output to transports
 - Optionally keeps a history of logs
 - All log messages can be tagged
 - `LogLevel`s are provided as well
 - Force logging enables output via `print` even if no transports available

 ## Filtering

 Two methods exist to allow for filtering of the log stream.

 - `Logger.filterUnless(tag:)`
 - `Logger.filterIf(tag:)`

 */
public class Logger {
    /// Shared logger object
    public static let shared: Logger = {
        let logger = Logger()
        logger.addTransport { print($0) }
        return logger
    }()

    private var data = SynchronizedData()

    private let startTime = DispatchTime.now()
    private let queue = DispatchQueue(label: "Swooft.Logger", qos: .utility)

    /**
     Transports are called asynchrnously, and this group allows you to wait for
     all logging to finish if the need arises
     */
    public let dispatchGroup = DispatchGroup()

    /// Set to true if you want the tags to be printed as well
    public var outputTags: Bool {
        get {
            return self.queue.sync {
                return self.data.outputTags
            }
        }
        set {
            self.queue.async { [weak self] in
                self?.data.outputTags = newValue
            }
        }
    }

    /// If this is true then it ignores all logs
    public var enabled: Bool {
        get {
            return self.queue.sync {
                return self.data.enabled
            }
        }
        set {
            self.queue.async { [weak self] in
                self?.data.enabled = newValue
            }
        }
    }

    /**
     Initializes a Logger object

     - parameter logHistorySize: How many entried to keep in the history
     */
    public init(logHistorySize: Int? = nil) {
        if let logHistorySize = logHistorySize {
            self.data.historyBuffer = RingBuffer(capacity: logHistorySize)
        }
    }

    /**
     Adding a transport allows you to tell the logger where the output goes to. You may add as
     many as you like.

     - parameter transport: function that is called with each log invocaton
     */
    public func addTransport(_ transport: @escaping (String) -> Void) {
        self.queue.sync {
            self.data.transports.append(transport)
        }
    }

    /// Filters log messages unless they are tagged with `tag`
    public func filterUnless(tag: String) {
        _ = self.queue.async { [weak self] in
            self?.data.allowedTags.insert(tag)
        }
    }

    /// Filters log messages unless they are tagged with any of `tags`
    public func filterUnless(tags: [String]) {
        self.queue.async { [weak self] in
            if let union = self?.data.allowedTags.union(tags) {
                self?.data.allowedTags = union
            }
        }
    }

    /// Filters log messages if they are tagged with `tag`
    public func filterIf(tag: String) {
        _ = self.queue.async { [weak self] in
            self?.data.ignoredTags.insert(tag)
        }
    }

    /// Filters log messages if they are tagged with any of `tags`
    public func filterIf(tags: [String]) {
        self.queue.async { [weak self] in
            if let union = self?.data.ignoredTags.union(tags) {
                self?.data.ignoredTags = union
            }
        }
    }

    /**
     Logs any `T` by using string interpolation

     - parameter object: autoclosure statment to be logged
     - parameter tag: a tag to apply to this log
     */
    public func log<T>(_ object: @autoclosure () -> T, tag: String, force: Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        self.log(object(), tags: [tag], force: force, file, function, line)
    }

    /**
     Logs any `T` by using string interpolation

     - parameter object: autoclosure statment to be logged
     - parameter tags: a set of tags to apply to this log
     */
    public func log<T>(level: LogLevel = .info, _ object: @autoclosure () -> T, tags explicitTags: [String] = [], force: Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        let data = self.queue.sync {
            return self.data
        }
        guard data.enabled || force || data.transports.count > 0 else {
            return
        }

        let thread = Thread.isMainThread ? "UI" : "BG"
        let threadID = pthread_mach_thread_np(pthread_self())
        let timestamp = self.startTime.elapsed

        let string = "\(object())"
        self.dispatchGroup.enter()
        self.queue.async { [weak self] in
            defer {
                self?.dispatchGroup.leave()
            }
            let functionName = function.components(separatedBy: "(").first ?? ""
            let fileName: String = {
                let name = URL(fileURLWithPath: file)
                    .deletingPathExtension().lastPathComponent
                let value = name.isEmpty ? "Unknown file" : name
                return value
            }()

            var allTags = [functionName, thread, fileName, level.rawValue]
            allTags.append(contentsOf: explicitTags)

            var shouldOutputToTransports = true
            if data.ignoredTags.count > 0 && data.ignoredTags.intersection(allTags).count > 0 {
                shouldOutputToTransports = false
            }

            if data.allowedTags.count > 0 && data.allowedTags.intersection(allTags).count == 0 {
                shouldOutputToTransports = false
            }

            guard shouldOutputToTransports || force else {
                return
            }

            var tagsString = ""
            if explicitTags.count > 0 && data.outputTags {
                tagsString = ",\(explicitTags.joined(separator: ","))"
            }

            let output = "[\(level.rawValue):\(String(format: "%.2f", timestamp))][\(thread):\(threadID),\(fileName):\(line),\(functionName)\(tagsString)] => \(string)"

            self?.data.historyBuffer?.append(output)

            if shouldOutputToTransports {
                for transport in data.transports {
                    transport(output)
                }
            }

            if force {
                print(output)
            }
        }
    }
}
