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
                expect(results[safe: 0]?.tag) == "3ms"
                expect(results[safe: 1]?.tag) == "2ms"
                expect(results[safe: 2]?.tag) == "1ms"
            }

            it("should output ascending results") {
                let configuration = ProfilerConfiguration(threadCount: 1, sampleCount: 1)
                let profiler = Profiler(label: "basic-math", configuration: configuration)
                profiler.profile(tag: "1ms") { sleep(for: .milliseconds(1)) }
                profiler.profile(tag: "2ms") { sleep(for: .milliseconds(2)) }
                profiler.profile(tag: "3ms") { sleep(for: .milliseconds(3)) }
                let results = profiler.results.ascending()
                expect(results.count) == 3
                expect(results[safe: 0]?.tag) == "1ms"
                expect(results[safe: 1]?.tag) == "2ms"
                expect(results[safe: 2]?.tag) == "3ms"
            }
        }
    }
}
