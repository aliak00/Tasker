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

public protocol Task: class {
    associatedtype SuccessValue
    typealias TaskResult = Result<SuccessValue>
    typealias ResultCallback = (TaskResult) -> Void
    func execute(completion: @escaping ResultCallback)
    var timeout: DispatchTimeInterval? { get }
    func didCancel(with _: TaskError)
}

public extension Task {
    var timeout: DispatchTimeInterval? {
        return nil
    }

    func didCancel(with _: TaskError) {}
}
