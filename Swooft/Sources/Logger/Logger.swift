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

private extension DispatchTime {
    var elapsed: Double {
        let nanoTime = DispatchTime.now().uptimeNanoseconds - self.uptimeNanoseconds
        return Double(nanoTime) / 1_000_000
    }
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
        //        logger.addTransport { print($0) }
        return logger
    }()

    private let startTime = DispatchTime.now()
    private let queue = DispatchQueue(label: "Swooft.Logger", qos: .utility)
    private let dispatchGroup = DispatchGroup()

    private var _enabled: Bool = true
    private var _outputTags: Bool = false
    private var transports: [(String) -> Void] = []
    private var allowedTags = Set<String>()
    private var ignoredTags = Set<String>()
    private var historyBuffer: RingBuffer<String>?

    /**
     Initializes a Logger object

     - parameter logHistorySize: How many entried to keep in the history
     */
    public init(logHistorySize: Int? = nil) {
        if let logHistorySize = logHistorySize {
            self.historyBuffer = RingBuffer(capacity: logHistorySize)
        }
        self.enabled = true
    }

    /**
     Transports are called asynchronously, if you need to wait till all logging output has been sent to
     all transports then this function blocks until that happens
     */
    public func waitTillAllLogsTransported() {
        self.dispatchGroup.wait()
    }

    /// Set to true if you want the tags to be printed as well
    public var outputTags: Bool {
        get {
            return self.queue.sync {
                return self._outputTags
            }
        }
        set {
            self.queue.async { [weak self] in
                self?._outputTags = newValue
            }
        }
    }

    /// If this is false then it ignores all logs
    public var enabled: Bool {
        get {
            return self.queue.sync {
                return self._enabled
            }
        }
        set {
            self.queue.async { [weak self] in
                self?._enabled = newValue
            }
        }
    }

    /**
     Adding a transport allows you to tell the logger where the output goes to. You may add as
     many as you like.

     - parameter transport: function that is called with each log invocaton
     */
    public func addTransport(_ transport: @escaping (String) -> Void) {
        self.queue.async { [weak self] in
            self?.transports.append(transport)
        }
    }

    public func removeTransports() {
        self.queue.async { [weak self] in
            self?.transports.removeAll()
        }
    }

    /// Filters log messages unless they are tagged with `tag`
    public func filterUnless(tag: String) {
        _ = self.queue.async { [weak self] in
            self?.allowedTags.insert(tag)
        }
    }

    /// Filters log messages unless they are tagged with any of `tags`
    public func filterUnless(tags: [String]) {
        self.queue.async { [weak self] in
            if let union = self?.allowedTags.union(tags) {
                self?.allowedTags = union
            }
        }
    }

    /// Filters log messages if they are tagged with `tag`
    public func filterIf(tag: String) {
        _ = self.queue.async { [weak self] in
            self?.ignoredTags.insert(tag)
        }
    }

    /// Filters log messages if they are tagged with any of `tags`
    public func filterIf(tags: [String]) {
        self.queue.async { [weak self] in
            if let union = self?.ignoredTags.union(tags) {
                self?.ignoredTags = union
            }
        }
    }

    /**
     Logs any `T` by using string interpolation

     - parameter object: autoclosure statment to be logged
     - parameter tag: a tag to apply to this log
     */
    public func log<T>(_ object: @escaping @autoclosure () -> T, tag: String, force: Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        self.log(object(), tags: [tag], force: force, file, function, line)
    }

    /**
     Logs any `T` by using string interpolation

     - parameter object: autoclosure statment to be logged
     - parameter tags: a set of tags to apply to this log
     */
    public func log<T>(level: LogLevel = .info, _ object: @autoclosure () -> T, tags explicitTags: [String] = [], force: Bool = false, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {

        let thread = Thread.isMainThread ? "UI" : "BG"
        let threadID = pthread_mach_thread_np(pthread_self())
        let timestamp = self.startTime.elapsed
        let string = "\(object())"

        self.dispatchGroup.enter()
        self.queue.async { [weak self] in
            defer {
                self?.dispatchGroup.leave()
            }
            guard let strongSelf = self else {
                return
            }
            guard (strongSelf._enabled && strongSelf.transports.count > 0) || force else {
                return
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
            if strongSelf.ignoredTags.count > 0 && strongSelf.ignoredTags.intersection(allTags).count > 0 {
                shouldOutputToTransports = false
            }

            if strongSelf.allowedTags.count > 0 && strongSelf.allowedTags.intersection(allTags).count == 0 {
                shouldOutputToTransports = false
            }

            guard shouldOutputToTransports || force else {
                return
            }

            var tagsString = ""
            if explicitTags.count > 0 && strongSelf._outputTags {
                tagsString = ",\(explicitTags.joined(separator: ","))"
            }

            let output = "[\(level.rawValue):\(String(format: "%.2f", timestamp))][\(thread):\(threadID),\(fileName):\(line),\(functionName)\(tagsString)] => \(string)"

            strongSelf.historyBuffer?.append(output)

            if shouldOutputToTransports {
                for transport in strongSelf.transports {
                    transport(output)
                }
            }

            if force {
                print(output)
            }
        }
    }
}
