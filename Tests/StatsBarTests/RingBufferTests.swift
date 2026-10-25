import Testing
import StatsBarCore

@Suite("RingBuffer Tests")
struct RingBufferTests {

    @Test("Initializes empty with exact capacity")
    func testInitialization() {
        let buffer = RingBuffer<Int>(capacity: 5)
        #expect(buffer.capacity == 5)
        #expect(buffer.currentCount == 0)
        #expect(buffer.elements.isEmpty)
        #expect(buffer.latest == nil)
    }

    @Test("Appends items and preserves chronological order")
    func testAppendAndOrder() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(10)
        buffer.append(20)

        #expect(buffer.currentCount == 2)
        #expect(buffer.elements == [10, 20])
        #expect(buffer.latest == 20)
    }

    @Test("Evicts oldest element when capacity is exceeded")
    func testCapacityEviction() {
        var buffer = RingBuffer<Int>(capacity: 3)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        #expect(buffer.elements == [1, 2, 3])

        // 4 overwrites 1
        buffer.append(4)
        #expect(buffer.currentCount == 3)
        #expect(buffer.elements == [2, 3, 4])
        #expect(buffer.latest == 4)

        // 5 overwrites 2
        buffer.append(5)
        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer.latest == 5)
    }
}
