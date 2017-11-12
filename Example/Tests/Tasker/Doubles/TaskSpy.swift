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

import Foundation
import Quick
import Nimble
@testable import Swooft

var kTaskSpyCounter = AtomicInt()

private class TaskSpyConfiguration: QuickConfiguration {
    override class func configure(_ configuration: Configuration) {
        configuration.afterEach {
            expect(kTaskSpyCounter.value).toEventually(equal(0))
        }
    }
}

extension TaskSpy where T == Void {
    convenience init() {
        self.init { $0(.success(())) }
    }
}

typealias SuccessTaskSpy = TaskSpy<Void>

class TaskSpy<T>: Task {
    typealias SuccessValue = T

    var executeCallCount = 0
    var executeBlock: (ResultCallback) -> Void
    var executeCallBackData: [AnyResult] = []

    init(executeBlock: (@escaping (ResultCallback) -> Void)) {
        self.executeBlock = executeBlock
        kTaskSpyCounter.getAndIncrement()
    }

    deinit {
        kTaskSpyCounter.getAndDecrement()
    }

    func execute(completion: @escaping ResultCallback) {
        let wrappedcompletionHandler: ResultCallback = { result in
            self.executeCallBackData.append(AnyResult(result))
            completion(result)
        }
        self.executeBlock(wrappedcompletionHandler)
        self.executeCallCount += 1
    }
}

