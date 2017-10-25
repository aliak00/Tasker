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

import Quick
import Nimble
@testable import Swooft

class ProfilerTests: QuickSpec {

    override func spec() {

        describe("profiler") {

            it("should get results for single profile") {
                let result = Profiler.profile(label: "1+1") {
                    _ = 1 + 1
                }
                expect(result["1+1"]) > 0.0
                expect(String(describing: result)).to(contain("1+1"))
            }

            it("should get results for multiple profilers") {
                let profiler = Profiler(label: "basic-math")

                profiler.profile(tag: "1+1") {
                    _ = 1 + 1
                }
                profiler.profile(tag: "1-1") {
                    _ = 1 - 1
                }

                let result = profiler.results
                expect(result["1+1"]) > 0.0
                expect(result["1-1"]) > 0.0

                let string = String(describing: result)
                expect(string).to(contain("basic-math"))
                expect(string).to(contain("1+1"))
                expect(string).to(contain("1-1"))
            }

            it("should show descending results") {
                let configuration = ProfilerConfiguration(threadCount: 1, sampleCount: 1)
                let profiler = Profiler(label: "basic-math", configuration: configuration)
                profiler.profile(tag: "1ms") { sleep(for: .milliseconds(1)) }
                profiler.profile(tag: "2ms") { sleep(for: .milliseconds(2)) }
                profiler.profile(tag: "3ms") { sleep(for: .milliseconds(3)) }
                let results = profiler.results.descending()
                expect(results.count) == 3
                expect(results[0].tag) == "3ms"
                expect(results[1].tag) == "2ms"
                expect(results[2].tag) == "1ms"
            }

            it("should output ascending results") {
                let configuration = ProfilerConfiguration(threadCount: 1, sampleCount: 1)
                let profiler = Profiler(label: "basic-math", configuration: configuration)
                profiler.profile(tag: "1ms") { sleep(for: .milliseconds(1)) }
                profiler.profile(tag: "2ms") { sleep(for: .milliseconds(2)) }
                profiler.profile(tag: "3ms") { sleep(for: .milliseconds(3)) }
                let results = profiler.results.ascending()
                expect(results.count) == 3
                expect(results[0].tag) == "1ms"
                expect(results[1].tag) == "2ms"
                expect(results[2].tag) == "3ms"
            }
        }

        describe("tests") {

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
}
