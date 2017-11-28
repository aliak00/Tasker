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
import Nimble
import Quick
@testable import Swooft

var kTaskSpyCounter = AtomicInt()

private class TaskSpyConfiguration: QuickConfiguration {
    override class func configure(_ configuration: Configuration) {
        configuration.afterEach {
            expect(kTaskSpyCounter.value).toEventually(equal(0))
        }
    }
}

class TaskSpy<T>: AnyTask<T> {
    var executeCallCount: Int {
        return self.executeCallBackData.count
    }

    var executeCallBackData: [AnyResult] = []

    override init(timeout: DispatchTimeInterval? = nil, execute: (@escaping (@escaping ResultCallback) -> Void)) {
        super.init(timeout: timeout, execute: execute)
        kTaskSpyCounter.getAndIncrement()
    }

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> Result<T>) {
        self.init(timeout: timeout) { completion in
            completion(execute())
        }
    }

    convenience init(timeout: DispatchTimeInterval? = nil, execute: @escaping () -> T) {
        self.init(timeout: timeout) { completion in
            completion(.success(execute()))
        }
    }

    deinit {
        kTaskSpyCounter.getAndDecrement()
    }

    override func execute(completion: @escaping ResultCallback) {
        let wrappedcompletion: ResultCallback = { [weak self] result in
            completion(result)
            self?.executeCallBackData.append(AnyResult(result))
        }
        self.executeThunk(wrappedcompletion)
    }
}
