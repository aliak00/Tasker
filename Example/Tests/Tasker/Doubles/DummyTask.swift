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
import Swooft

class DummyTask: Task {
    typealias SuccessValue = Void
    func execute(completion: @escaping (Result<Void>) -> Void) {
        completion(.success(()))
    }
}

let kDummyTask = DummyTask()
