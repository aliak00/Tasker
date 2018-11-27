import Foundation

struct Weak<T: AnyObject> {
    weak var value: T?
    init(_ value: T?) {
        self.value = value
    }
}
