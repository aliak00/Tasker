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

public protocol LoggerEnabled {
    static var LogTag: String { get }
    var logger: Logger { get }
    func log<T>(_ object: @autoclosure () -> T, _ file: String, _ function: String, _ line: Int)
    func log<T>(_ object: @autoclosure () -> T, tag: String, _ file: String, _ function: String, _ line: Int)
    func log<T>(_ object: @autoclosure () -> T, tags: [String], _ file: String, _ function: String, _ line: Int)
}

extension LoggerEnabled {
    public static var LogTag: String {
        return String(describing: type(of: self))
    }

    public func log<T>(_ object: @autoclosure () -> T, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        self.log(object(), tags: [], file, function, line)
    }

    public func log<T>(_ object: @autoclosure () -> T, tag: String, _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        self.log(object(), tags: [tag], file, function, line)
    }

    public func log<T>(_ object: @autoclosure () -> T, tags: [String], _ file: String = #file, _ function: String = #function, _ line: Int = #line) {
        var tags = tags
        tags.append(Self.LogTag)
        self.logger.log(object(), tags: tags, file, function, line)
    }
}
