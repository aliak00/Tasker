//
//  DummyTask.swift
//  Tasker
//
//  Created by Ali Akhtarzada on 7/2/17.
//  Copyright © 2017 CocoaPods. All rights reserved.
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
