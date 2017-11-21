//
// Copyright 2017 Ali Akhtarzada
//
// Licensed under the Apache License, Version 2.0 (the 'License');
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//

import Quick
import Swooft

class LoggingProfilerTests: QuickSpec {

    override func spec() {
        it("logging") {
            let configuration = ProfilerConfiguration(threadCount: 4, sampleCount: 10000)
            let profiler = Profiler(label: "logging", configuration: configuration)

            func noop(_: String) {}

            let data = "hello this is some data".data(using: .utf8)!

            //
            // Test performance of synchronous logging
            //
            let syncLogger = Logger(synchronousOutput: true)
            profiler.profile(label: "sync with self") {
                syncLogger.log(from: self, "hello \(data)")
            }
            profiler.profile(label: "sync without self") {
                syncLogger.log("hello \(data)")
            }
            syncLogger.addTransport({noop($0)})
            profiler.profile(label: "sync without self with transport") {
                syncLogger.log("hello \(data)")
            }
            profiler.profile(label: "sync with self with transport") {
                syncLogger.log(from: self, "hello \(data)")
            }

            //
            // Test performance of asynchronous logging
            //
            let asyncLogger = Logger(synchronousOutput: false)
            profiler.profile(label: "async with self") {
                asyncLogger.log(from: self, "hello \(data)")
            }
            asyncLogger.waitTillAllLogsTransported()
            profiler.profile(label: "async without self") {
                asyncLogger.log("hello \(data)")
            }
            asyncLogger.addTransport({noop($0)})
            asyncLogger.waitTillAllLogsTransported()
            profiler.profile(label: "async without self with transport") {
                asyncLogger.log("hello \(data)")
            }
            asyncLogger.waitTillAllLogsTransported()
            profiler.profile(label: "async with self with transport") {
                asyncLogger.log(from: self, "hello \(data)")
            }
            asyncLogger.waitTillAllLogsTransported()

            print(profiler.results)
        }
    }
}
