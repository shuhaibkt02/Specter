import Foundation

/// A fixed-capacity, FIFO circular buffer for real-time telemetry sparklines.
/// Kept purely in memory to guarantee zero SSD write wear.
public struct RingBuffer<Element: Sendable>: Sendable {
    private var storage: [Element?]
    private var writeIndex: Int = 0
    private var count: Int = 0
    public let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0, "Capacity must be greater than zero.")
        self.capacity = capacity
        self.storage = [Element?](repeating: nil, count: capacity)
    }

    /// Appends a new sample to the buffer, overwriting the oldest sample when full.
    public mutating func append(_ element: Element) {
        storage[writeIndex] = element
        writeIndex = (writeIndex + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    /// Returns all elements in chronological order (oldest to newest).
    public var elements: [Element] {
        var result: [Element] = []
        result.reserveCapacity(count)
        
        let startIndex = count < capacity ? 0 : writeIndex
        for i in 0..<count {
            let index = (startIndex + i) % capacity
            if let item = storage[index] {
                result.append(item)
            }
        }
        return result
    }

    /// Returns the current number of elements in the buffer.
    public var currentCount: Int {
        count
    }

    /// Returns the most recent element appended, or nil if empty.
    public var latest: Element? {
        guard count > 0 else { return nil }
        let lastIndex = (writeIndex - 1 + capacity) % capacity
        return storage[lastIndex]
    }
}
