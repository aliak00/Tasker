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

class OwnedTaskHandle: TaskHandle {
    fileprivate weak var owner: TaskManager?

    public let identifier: Int

    static var counter = AtomicInt()

    init(owner: TaskManager) {
        self.identifier = type(of: self).counter.getAndIncrement()
        self.owner = owner
    }

    public func start() {
        self.owner?.start(handle: self)
    }

    public func cancel() {
        self.owner?.cancel(handle: self, with: .cancelled)
    }

    public var state: TaskState {
        return self.owner?.taskState(for: self) ?? .finished
    }

    func discard() {
        self.owner?.cancel(handle: self, with: nil)
    }
}

extension OwnedTaskHandle: CustomStringConvertible {
    var description: String {
        var ownerIdentifier: String = "<unowned>."
        if let owner = self.owner {
            ownerIdentifier = "\(owner.identifier)."
        }

        return "handle.\(ownerIdentifier)\(self.identifier)"
    }
}

extension OwnedTaskHandle: Hashable {
    var hashValue: Int {
        return self.identifier
    }

    static func == (lhs: OwnedTaskHandle, rhs: OwnedTaskHandle) -> Bool {
        return lhs.identifier == rhs.identifier
    }
}
