import Foundation

class SynchronizedArray<Element>: ExpressibleByArrayLiteral {
    required init(arrayLiteral elements: Element...) {
        self.array = elements
    }

    required init(elements: [Element]) {
        self.array = elements
    }

    private var array: [Element] = []
    private let queue = DispatchQueue(label: "Tasker.Collections.SynchronizedArray")

    init() {}

    var data: [Element] {
        get {
            self.queue.sync {
                self.array
            }
        }
        set {
            self.queue.async {
                self.array = newValue
            }
        }
    }

    subscript(index: Int) -> Element {
        get {
            self.queue.sync {
                self.array[index]
            }
        }
        set {
            self.queue.async(flags: .barrier) {
                self.array[index] = newValue
            }
        }
    }

    var count: Int {
        self.queue.sync {
            self.array.count
        }
    }

    func append(_ element: Element) {
        self.queue.async(flags: .barrier) {
            self.array.append(element)
        }
    }
}
