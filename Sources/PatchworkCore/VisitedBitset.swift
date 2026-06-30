import Foundation

/// A compact, fixed-capacity bitset recording which ZCTAs the user has physically entered.
///
/// Locked V1 decision #5: coverage is stored as a compact visited-ZCTA bitset. Each ZCTA
/// is identified by a stable `ZCTAIndex` in `0..<capacity`. A national bundle has ~33k
/// ZCTAs, so the full bitset is ~33000/8 ≈ 4 KB — cheap to keep in memory and persist.
///
/// The bitset is the single source of truth for user progress. Rollups (city/county/state/
/// country) are derived from it at view time via weighted sums; nothing else is persisted.
public struct VisitedBitset: Equatable, Sendable {
    /// Number of bits (== number of ZCTAs in the active dataset).
    public let capacity: Int

    /// Backing storage, 64 bits per word, little bit-endian within a word.
    private(set) var words: [UInt64]

    private static let bitsPerWord = 64

    public init(capacity: Int) {
        precondition(capacity >= 0, "capacity must be non-negative")
        self.capacity = capacity
        let wordCount = (capacity + Self.bitsPerWord - 1) / Self.bitsPerWord
        self.words = Array(repeating: 0, count: wordCount)
    }

    init(capacity: Int, words: [UInt64]) {
        self.capacity = capacity
        self.words = words
    }

    @inline(__always)
    private static func wordAndBit(_ index: ZCTAIndex) -> (word: Int, mask: UInt64) {
        (index / bitsPerWord, UInt64(1) << UInt64(index % bitsPerWord))
    }

    /// Returns true if `index` is within the addressable range.
    @inline(__always)
    public func isValidIndex(_ index: ZCTAIndex) -> Bool {
        index >= 0 && index < capacity
    }

    /// Marks the ZCTA at `index` as visited. Out-of-range indices are ignored.
    /// - Returns: true if this call changed the bit (it was previously unvisited).
    @discardableResult
    public mutating func insert(_ index: ZCTAIndex) -> Bool {
        guard isValidIndex(index) else { return false }
        let (word, mask) = Self.wordAndBit(index)
        let wasSet = (words[word] & mask) != 0
        words[word] |= mask
        return !wasSet
    }

    /// Clears the visited bit for `index`. Out-of-range indices are ignored.
    @discardableResult
    public mutating func remove(_ index: ZCTAIndex) -> Bool {
        guard isValidIndex(index) else { return false }
        let (word, mask) = Self.wordAndBit(index)
        let wasSet = (words[word] & mask) != 0
        words[word] &= ~mask
        return wasSet
    }

    /// Returns true if the ZCTA at `index` has been visited.
    @inline(__always)
    public func contains(_ index: ZCTAIndex) -> Bool {
        guard isValidIndex(index) else { return false }
        let (word, mask) = Self.wordAndBit(index)
        return (words[word] & mask) != 0
    }

    /// Removes all visited bits.
    public mutating func removeAll() {
        for i in words.indices { words[i] = 0 }
    }

    /// Total number of visited ZCTAs.
    public var count: Int {
        words.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    public var isEmpty: Bool {
        words.allSatisfy { $0 == 0 }
    }

    /// Calls `body` once per visited ZCTA index, in ascending order.
    public func forEachVisited(_ body: (ZCTAIndex) -> Void) {
        for (wordIndex, word) in words.enumerated() {
            guard word != 0 else { continue }
            var bits = word
            let base = wordIndex * Self.bitsPerWord
            while bits != 0 {
                let bit = bits.trailingZeroBitCount
                body(base + bit)
                bits &= bits - 1 // clear lowest set bit
            }
        }
    }

    /// The set of visited indices, ascending.
    public var visitedIndices: [ZCTAIndex] {
        var result: [ZCTAIndex] = []
        result.reserveCapacity(count)
        forEachVisited { result.append($0) }
        return result
    }

    /// Returns the number of visited indices that fall within `indices` — the core
    /// primitive behind region rollups (visited ZCTAs ∩ region member ZCTAs).
    public func countVisited(in indices: some Sequence<ZCTAIndex>) -> Int {
        var n = 0
        for i in indices where contains(i) { n += 1 }
        return n
    }
}

// MARK: - Binary serialization

extension VisitedBitset {
    /// Magic prefix `PWBS` (Patchwork BitSet) for the on-disk/export format.
    private static let magic: [UInt8] = [0x50, 0x57, 0x42, 0x53]
    private static let formatVersion: UInt8 = 1

    /// Serializes to a compact, versioned binary blob:
    /// `[magic(4)][version(1)][capacity(UInt32 LE)][words(UInt64 LE)...]`.
    public func serialized() -> Data {
        var data = Data()
        data.append(contentsOf: Self.magic)
        data.append(Self.formatVersion)
        var cap = UInt32(capacity).littleEndian
        withUnsafeBytes(of: &cap) { data.append(contentsOf: $0) }
        for word in words {
            var w = word.littleEndian
            withUnsafeBytes(of: &w) { data.append(contentsOf: $0) }
        }
        return data
    }

    public enum DeserializationError: Error, Equatable {
        case tooShort
        case badMagic
        case unsupportedVersion(UInt8)
        case truncatedWords
    }

    /// Reconstructs a bitset from `serialized()` output.
    public init(serialized data: Data) throws {
        // Work on a contiguous copy so byte offsets are stable regardless of `Data` slicing.
        let bytes = [UInt8](data)
        guard bytes.count >= 9 else { throw DeserializationError.tooShort }
        guard Array(bytes[0..<4]) == Self.magic else { throw DeserializationError.badMagic }
        let version = bytes[4]
        guard version == Self.formatVersion else {
            throw DeserializationError.unsupportedVersion(version)
        }
        let capacity = Int(UInt32(bytes[5]) | (UInt32(bytes[6]) << 8) |
                           (UInt32(bytes[7]) << 16) | (UInt32(bytes[8]) << 24))
        let expectedWordCount = (capacity + 63) / 64
        let wordBytes = bytes.count - 9
        guard wordBytes == expectedWordCount * 8 else {
            throw DeserializationError.truncatedWords
        }
        var words = [UInt64]()
        words.reserveCapacity(expectedWordCount)
        var offset = 9
        for _ in 0..<expectedWordCount {
            var w: UInt64 = 0
            for b in 0..<8 {
                w |= UInt64(bytes[offset + b]) << (8 * b)
            }
            words.append(w)
            offset += 8
        }
        self.init(capacity: capacity, words: words)
    }
}
