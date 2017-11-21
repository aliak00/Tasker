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

class LockingProfilerTests: QuickSpec {

    override func spec() {
        xit("locks") {
            let configuration = ProfilerConfiguration(threadCount: 100, sampleCount: 10000)
            let profiler = Profiler(label: "locking", configuration: configuration)

            var x = 0
            let locka = NSLock()
            profiler.profile(tag: "nslock") {
                locka.lock()
                x += 1
                locka.unlock()
            }

            let lockb = NSRecursiveLock()
            profiler.profile(tag: "nsrecursivelock") {
                lockb.lock()
                x += 1
                lockb.unlock()
            }

            let lockc = PosixLock(kind: .normal)
            profiler.profile(tag: "plock") {
                lockc.lock()
                x += 1
                lockc.unlock()
            }

            let lockd = PosixLock(kind: .recursive)
            profiler.profile(tag: "precursivelock") {
                lockd.lock()
                x += 1
                lockd.unlock()
            }

            print(profiler.results)
        }
    }
}
