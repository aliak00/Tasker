import Foundation

/**
 You can specify log levels when calling any of the log functions of `Logger`
*/
public enum LogLevel: String {
    ///
    case debug = "D"
    ///
    case info = "I"
    ///
    case verbose = "V"
    ///
    case error = "E"
    ///
    case warn = "W"
}
