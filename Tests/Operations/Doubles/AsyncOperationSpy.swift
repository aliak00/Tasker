// //
// // Copyright 2017 Ali Akhtarzada
// //
// // Licensed under the Apache License, Version 2.0 (the 'License');
// // you may not use this file except in compliance with the License.
// // You may obtain a copy of the License at
// //
// // http://www.apache.org/licenses/LICENSE-2.0
// //

import Foundation
import Tasker

class AsyncOperationSpy: AsyncOperation {
    var executorCallCount: Int = 0
    var startCallCount: Int = 0
    var finishCallCount: Int = 0
    var cancelCallCount: Int = 0

    override init(executor: @escaping (AsyncOperation) -> Void) {
        super.init { op in
            executor(op)
            (op as! AsyncOperationSpy).executorCallCount += 1
        }
    }

    override func start() {
        super.start()
        self.startCallCount += 1
    }

    override func finish() {
        super.finish()
        self.finishCallCount += 1
    }

    override func cancel() {
        super.cancel()
        self.cancelCallCount += 1
    }
}
