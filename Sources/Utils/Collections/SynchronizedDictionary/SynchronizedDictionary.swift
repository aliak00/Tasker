import Foundation

class SynchronizedDictionary<Key: Hashable, Value> {
    private var dictionary: [Key: Value] = [:]
    private let queue = DispatchQueue(label: "Tasker.Collections.SynchronizedDictionary", attributes: [.concurrent])

    init() {}

    var data: [Key: Value] {
        self.queue.sync {
            self.dictionary
        }
    }

    subscript(key: Key) -> Value? {
        get {
            self.queue.sync {
                self.dictionary[key]
            }
        }
        set {
            self.queue.async(flags: .barrier) { [weak self] in
                guard let newValue = newValue else {
                    self?.dictionary[key] = nil
                    return
                }
                self?.dictionary[key] = newValue
            }
        }
    }
}
