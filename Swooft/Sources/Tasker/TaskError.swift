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

public enum TaskError: Error {
    case reactorFailed(type: TaskReactor.Type, error: Error)
    case reactorTimedOut(type: TaskReactor.Type)
    case cancelled
    case timedOut
    case unknown
}
