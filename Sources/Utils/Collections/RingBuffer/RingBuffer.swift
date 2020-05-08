import Foundation

struct RingBuffer<Element> {
    fileprivate var array: [Element] = []
    private var currentIndex = 0
    let capacity: Int

    init(desiredCapacity: Int, initialElements: [Element]) {
        self.init(capacity: Swift.max(desiredCapacity, initialElements.count))
        self.array.append(contentsOf: initialElements)
    }

    init(elementsDictatingCapacity: [Element]) {
        self.init(capacity: elementsDictatingCapacity.count)
        self.array = elementsDictatingCapacity
    }

    init(capacity: Int) {
        self.capacity = capacity
        self.array.reserveCapacity(capacity)
    }

    mutating func append(_ element: Element) {
        if self.array.count < self.capacity {
            self.array.append(element)
        } else {
            self.array[self.currentIndex % self.array.count] = element
            self.currentIndex += 1
        }
    }
}

extension RingBuffer: Equatable where Element: Equatable {
    static func == (lhs: RingBuffer<Element>, rhs: RingBuffer<Element>) -> Bool {
        lhs.array == rhs.array
    }
}

extension RingBuffer: MutableCollection, RandomAccessCollection {
    func index(after i: Int) -> Int {
        i + 1
    }

    var startIndex: Int {
        0
    }

    var endIndex: Int {
        self.array.count
    }

    subscript(index: Int) -> Element {
        get {
            self.array[(self.currentIndex + index) % self.array.count]
        }
        set(element) {
            self.array[(self.currentIndex + index) % self.array.count] = element
        }
    }
}

extension RingBuffer: CustomStringConvertible {
    var description: String {
        self.array.description
    }
}
