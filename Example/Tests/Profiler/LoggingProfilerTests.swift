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
import Nimble
import Swooft

class LoggingProfilerTests: QuickSpec {

    override func spec() {
        xit("tasks") {
            let configuration = ProfilerConfiguration(threadCount: 2, sampleCount: 10)
            let profiler = Profiler(label: "", configuration: configuration)

            let taskManager = TaskManager()
            func noop(_: String) {}
            Logger.shared.addTransport { noop($0) }
            profiler.profile(tag: "with logging") {

                var handles: [TaskHandle] = []
                for _ in 0..<400 {
                    handles.append(taskManager.add(task: DummyTask()))
                }
                taskManager.waitTillAllTasksFinished()
                for handle in handles {
                    assert(handle.state == .finished)
                }
            }

            Logger.shared.removeTransports()
            profiler.profile(tag: "without logging") {
                var handles: [TaskHandle] = []
                for _ in 0..<400 {
                    handles.append(taskManager.add(task: DummyTask()))
                }
                taskManager.waitTillAllTasksFinished()
                for handle in handles {
                    assert(handle.state == .finished)
                }
            }

            print(profiler.results)
        }
    }
}
