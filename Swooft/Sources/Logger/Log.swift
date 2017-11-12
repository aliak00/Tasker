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

public func log<T>(
    level: LogLevel = .info,
    _ object: @autoclosure () -> T,
    tag: String? = nil,
    tags: [String] = [],
    force: Bool = false,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    var tags = tags
    if let tag = tag {
        tags.append(tag)
    }
    Logger.shared.log(level: level, object(), tags: tags, force: force, file, function, line)
}

public func log<T, S>(
    level: LogLevel = .info,
    from _: S?,
    _ object: @autoclosure () -> T,
    tag: String? = nil,
    tags: [String] = [],
    force: Bool = false,
    file: String = #file,
    function: String = #function,
    line: Int = #line
) {
    var tags = tags
    tags.append(String(describing: S.self))
    log(level: level, object(), tag: tag, tags: tags, force: force, file: file, function: function, line: line)
}
