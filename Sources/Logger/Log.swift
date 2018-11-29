import Foundation

func log<T>(
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

func log<T, S>(
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
