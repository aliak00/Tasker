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

class LockingProfilerTests: QuickSpec {

    override func spec() {
        it("locks") {
            let configuration = ProfilerConfiguration(threadCount: 100, sampleCount: 1000)
            let profiler = Profiler(label: "locking", configuration: configuration)

            var x = 0
            let locka = NSLock()
            profiler.profile(label: "nslock") {
                locka.lock()
                x += 1
                locka.unlock()
            }

            let lockb = NSRecursiveLock()
            profiler.profile(label: "nsrecursivelock") {
                lockb.lock()
                x += 1
                lockb.unlock()
            }

            let lockc = PosixLock(kind: .normal)
            profiler.profile(label: "plock") {
                lockc.lock()
                x += 1
                lockc.unlock()
            }

            let lockd = PosixLock(kind: .recursive)
            profiler.profile(label: "precursivelock") {
                lockd.lock()
                x += 1
                lockd.unlock()
            }

            print(profiler.results)
        }
    }
}
