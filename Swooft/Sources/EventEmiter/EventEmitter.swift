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

/*
 A lot of code here is explained in Mike Ash's "Let's Build Swift Notifications" article:
 https://mikeash.com/pyblog/friday-qa-2015-01-23-lets-build-swift-notifications.html
 */

public class EventEmitter<Parameters> {

    public typealias Handle = EventEmitterHandle<Parameters>

    private let queue = DispatchQueue(label: "Swooft.EventEmitter", attributes: [.concurrent])
    private let handles = SynchronizedSet<Handle>()
    private var descriptionText: String

    public init(description: String) {
        self.descriptionText = description
    }

    public init() {
        self.descriptionText = "\(EventEmitter<Parameters>.self)"
    }

    @discardableResult
    public func register(_ closure: @escaping (Parameters) -> Void) -> Handle {
        let handle = Handle(closure: closure)
        self.handles.insert(handle)
        return handle
    }

    @discardableResult
    public func register<T: AnyObject>(_ object: T, method: @escaping (T) -> (Parameters) -> Void) -> Handle {
        let handle = Handle(object: object, method: method)
        self.handles.insert(handle)
        return handle
    }

    public func unregister(_ handle: Handle) {
        self.handles.remove(handle)
    }

    private func compactAndCaptureHandlers() -> [(delegate: Handle.DelegateType.Capture, description: String)] {
        var handlers: [(Handle.DelegateType.Capture, String)] = []
        self.handles.getAndMutate { set in
            let validHandles = set.filter {
                if let capture = $0.delegate.capture() {
                    handlers.append((capture, $0.descriptionText))
                    return true
                }
                return false
            }
            return Set(validHandles)
        }
        return handlers
    }

    public func emitSync(_ parameters: Parameters) {
        log(level: .verbose, from: self, "\(self.descriptionText) will emit on \(self.handles.count) handles")
        let handlers = self.compactAndCaptureHandlers()
        for handler in handlers {
            log(from: self, "\(self.descriptionText) -> \(handler.description)")
            handler.delegate(parameters)
        }
    }

    public func emitAsync(_ parameters: Parameters) {
        log(level: .verbose, from: self, "\(self.descriptionText) will emit on \(self.handles.count) handles")
        let handlers = self.compactAndCaptureHandlers()
        let descriptionText = self.descriptionText
        self.queue.async {
            for handler in handlers {
                log(from: self, "\(descriptionText) -> \(handler.description)")
                handler.delegate(parameters)
            }
        }
    }
}
