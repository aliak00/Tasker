import Foundation

public class SynchronizedDictionary<Key: Hashable, Value> {
    var dictionary: [Key: Value] = [:]
    let queue = DispatchQueue(label: "Swooft.Collections.SynchronizedDictionary", attributes: [.concurrent])

    public init() {}

    public subscript(key: Key) -> Value? {
        get {
            return self.queue.sync {
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
