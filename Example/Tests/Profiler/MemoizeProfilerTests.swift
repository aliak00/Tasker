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

class MemoizeProfilerTests: QuickSpec {

    override func spec() {
        xit("memoize or get path component") {
            //
            // This benchmark simlulates logging from X number of file and how much speed
            // up or down there is with different cache sizes for file names
            //
            // The logger logs the #file and passes that toURL(fileURLWithPath:) and then
            // cuts off the path and extension to leave only the filename. It also optionally
            // memoizes #file => filename. This benchmark seems when and if that's actually
            // useful
            //
            // Results show that a capacity of cache capacity of 100~120 does 50% better than
            // if there's no caching and if you have about 100 files you are doing any logging
            // from
            //
            let configuration = ProfilerConfiguration(threadCount: 2, sampleCount: 10)
            let profiler = Profiler(label: "memoize or get path component", configuration: configuration)

            let numberOfFiles: UInt32 = 100
            let numberOfLogs = 3000

            var files: [String] = []
            for i in 0..<numberOfLogs {
                files.append("some/path/\(Int(Float(arc4random()) / Float(UInt32.max) * 100)).ext")
            }

            func noop(_: String) {}

            for capacity in [5, 20, 50, 75, 100, 120, 180, 200] {
                let cache = Cache<String, String>(capacity: capacity)
                profiler.profile(tag: "memo-\(capacity)") {
                    for file in files {
                        let name: String = {
                            if let name = cache[file] {
                                return name
                            }
                            let name = URL(fileURLWithPath: file)
                                .deletingPathExtension().lastPathComponent
                            let value = name.isEmpty ? "Unknown file" : name
                            cache[file] = value
                            return value
                        }()
                        noop(name)
                    }
                }
            }

            profiler.profile(tag: "no-memo") {
                for file in files {
                    let name: String = {
                        let name = URL(fileURLWithPath: file)
                            .deletingPathExtension().lastPathComponent
                        let value = name.isEmpty ? "Unknown file" : name
                        return value
                    }()
                    noop(name)
                }
            }

            print(profiler.results)
        }
    }
}
