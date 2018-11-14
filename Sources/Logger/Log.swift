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
    Logger.shared.log(level: level, object, tags: tags, force: force, file, function, line)
}

public func log<T, S>(
    level: LogLevel = .info,
    from type: S?,
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
    Logger.shared.log(level: level, from: type, object, tags: tags, force: force, file, function, line)
}