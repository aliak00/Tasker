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
@testable import Swooft

class LockingProfilerTests: QuickSpec {

    override func spec() {
        xit("locks") {
            let configuration = ProfilerConfiguration(threadCount: 100, sampleCount: 500)
            let profiler = Profiler(label: "locking", configuration: configuration)

            let locka = NSLock()
            profiler.profile(tag: "nslock") {
                locka.lock()
                locka.unlock()
            }

            let lockb = NSRecursiveLock()
            profiler.profile(tag: "nsrecursivelock") {
                lockb.lock()
                lockb.unlock()
            }

            let lockc = PThreadMutex(kind: .normal)
            profiler.profile(tag: "plock") {
                lockc.lock()
                lockc.unlock()
            }

            let lockd = PThreadMutex(kind: .recursive)
            profiler.profile(tag: "precursivelock") {
                lockd.lock()
                lockd.unlock()
            }

            print(profiler.results)
        }
    }
}

