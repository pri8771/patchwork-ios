import XCTest
@testable import PatchworkCore

final class VisitedBitsetTests: XCTestCase {

    func testInsertContainsAndCount() {
        var bs = VisitedBitset(capacity: 200)
        XCTAssertTrue(bs.isEmpty)
        XCTAssertEqual(bs.count, 0)

        XCTAssertTrue(bs.insert(0))    // newly set
        XCTAssertTrue(bs.insert(63))   // word boundary
        XCTAssertTrue(bs.insert(64))   // next word
        XCTAssertTrue(bs.insert(199))  // last valid bit
        XCTAssertFalse(bs.insert(0))   // already set → no change

        XCTAssertEqual(bs.count, 4)
        XCTAssertTrue(bs.contains(0))
        XCTAssertTrue(bs.contains(63))
        XCTAssertTrue(bs.contains(64))
        XCTAssertTrue(bs.contains(199))
        XCTAssertFalse(bs.contains(1))
    }

    func testOutOfRangeIsIgnored() {
        var bs = VisitedBitset(capacity: 10)
        XCTAssertFalse(bs.insert(10))   // == capacity, invalid
        XCTAssertFalse(bs.insert(-1))
        XCTAssertFalse(bs.contains(10))
        XCTAssertFalse(bs.contains(-1))
        XCTAssertEqual(bs.count, 0)
    }

    func testRemoveAndRemoveAll() {
        var bs = VisitedBitset(capacity: 100)
        bs.insert(5); bs.insert(50); bs.insert(99)
        XCTAssertTrue(bs.remove(50))
        XCTAssertFalse(bs.remove(50))   // already clear
        XCTAssertFalse(bs.contains(50))
        XCTAssertEqual(bs.count, 2)
        bs.removeAll()
        XCTAssertTrue(bs.isEmpty)
    }

    func testForEachVisitedAscendingOrder() {
        var bs = VisitedBitset(capacity: 300)
        let expected = [3, 64, 65, 128, 299]
        for i in expected.shuffled() { bs.insert(i) }
        var seen: [ZCTAIndex] = []
        bs.forEachVisited { seen.append($0) }
        XCTAssertEqual(seen, expected)
        XCTAssertEqual(bs.visitedIndices, expected)
    }

    func testCountVisitedInRegion() {
        var bs = VisitedBitset(capacity: 100)
        for i in [10, 20, 30, 40] { bs.insert(i) }
        XCTAssertEqual(bs.countVisited(in: [10, 11, 20, 21, 30]), 3)
        XCTAssertEqual(bs.countVisited(in: [1, 2, 3]), 0)
    }

    func testSerializationRoundTrip() throws {
        var bs = VisitedBitset(capacity: 1000)
        for i in stride(from: 0, to: 1000, by: 7) { bs.insert(i) }
        let data = bs.serialized()
        let restored = try VisitedBitset(serialized: data)
        XCTAssertEqual(restored, bs)
        XCTAssertEqual(restored.count, bs.count)
        XCTAssertEqual(restored.capacity, 1000)
    }

    func testSerializationRejectsCorruptData() {
        XCTAssertThrowsError(try VisitedBitset(serialized: Data([0x00, 0x01])))
        // Good magic + version, but truncated word payload.
        var data = Data([0x50, 0x57, 0x42, 0x53, 0x01])
        var cap = UInt32(128).littleEndian
        withUnsafeBytes(of: &cap) { data.append(contentsOf: $0) }
        XCTAssertThrowsError(try VisitedBitset(serialized: data)) { error in
            XCTAssertEqual(error as? VisitedBitset.DeserializationError, .truncatedWords)
        }
    }

    func testEmptyBitsetSerialization() throws {
        let bs = VisitedBitset(capacity: 0)
        let restored = try VisitedBitset(serialized: bs.serialized())
        XCTAssertEqual(restored.capacity, 0)
        XCTAssertEqual(restored.count, 0)
    }
}
