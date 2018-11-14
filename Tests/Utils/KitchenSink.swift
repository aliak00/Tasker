import Foundation

func sleep(for interval: DispatchTimeInterval) {
    switch interval {
    case let .microseconds(value):
        usleep(useconds_t(value))
    case let .milliseconds(value):
        usleep(useconds_t(1000 * value))
    case let .nanoseconds(value):
        var requiredTimespec = timespec(tv_sec: 0, tv_nsec: value)
        withUnsafePointer(to: &requiredTimespec) { ptr in
            let actualTimespecPointer = UnsafeMutablePointer<timespec>.init(bitPattern: 0)
            nanosleep(ptr, actualTimespecPointer)
        }
    case let .seconds(value):
        usleep(useconds_t(1000 * 1000 * value))
    case .never:
        break
    }
}
