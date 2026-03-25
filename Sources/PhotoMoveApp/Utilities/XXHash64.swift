import Foundation

// MARK: - XXHash64 Streaming Hasher
// Reference: https://github.com/Cyan4973/xxHash/blob/dev/doc/xxhash_spec.md

struct XXHash64Hasher: Sendable {

    // xxHash64 prime constants
    private static let p1: UInt64 = 0x9E3779B185EBCA87
    private static let p2: UInt64 = 0xC2B2AE3D27D4EB4F
    private static let p3: UInt64 = 0x165667B19E3779F9
    private static let p4: UInt64 = 0x85EBCA77C2B2AE63
    private static let p5: UInt64 = 0x27D4EB2F165667C5

    private var v1: UInt64
    private var v2: UInt64
    private var v3: UInt64
    private var v4: UInt64
    private var totalLen: UInt64 = 0
    private var memBuffer: [UInt8] = []
    // M-34 FIX: Guard against re-finalization
    private var isFinalized: Bool = false
    private var cachedResult: UInt64 = 0

    init(seed: UInt64 = 0) {
        v1 = seed &+ Self.p1 &+ Self.p2
        v2 = seed &+ Self.p2
        v3 = seed
        v4 = seed &- Self.p1
    }

    mutating func update(data: Data) {
        totalLen &+= UInt64(data.count)
        memBuffer.append(contentsOf: data)
        processBlocks()
    }

    mutating func finalize() -> UInt64 {
        // M-34 FIX: Return cached result if already finalized
        if isFinalized { return cachedResult }
        var h: UInt64

        if totalLen >= 32 {
            h = Self.rotl(v1, 1) &+ Self.rotl(v2, 7) &+ Self.rotl(v3, 12) &+ Self.rotl(v4, 18)
            h = Self.mergeRound(h, val: v1)
            h = Self.mergeRound(h, val: v2)
            h = Self.mergeRound(h, val: v3)
            h = Self.mergeRound(h, val: v4)
        } else {
            h = v3 &+ Self.p5
        }

        h &+= totalLen

        let remaining = memBuffer
        var i = 0

        while i + 8 <= remaining.count {
            let k = Self.readLE64(remaining, offset: i)
            h ^= Self.xxhRound(0, input: k)
            h = Self.rotl(h, 27) &* Self.p1 &+ Self.p4
            i += 8
        }

        while i + 4 <= remaining.count {
            let k = UInt64(Self.readLE32(remaining, offset: i))
            h ^= k &* Self.p1
            h = Self.rotl(h, 23) &* Self.p2 &+ Self.p3
            i += 4
        }

        while i < remaining.count {
            h ^= UInt64(remaining[i]) &* Self.p5
            h = Self.rotl(h, 11) &* Self.p1
            i += 1
        }

        // Avalanche
        h ^= h >> 33
        h &*= Self.p2
        h ^= h >> 29
        h &*= Self.p3
        h ^= h >> 32

        isFinalized = true
        cachedResult = h
        return h
    }

    mutating func finalizeHex() -> String {
        String(format: "%016llx", finalize())
    }

    // MARK: - Private

    private mutating func processBlocks() {
        guard memBuffer.count >= 32 else { return }

        let blocksEnd = (memBuffer.count / 32) * 32

        for blockStart in stride(from: 0, to: blocksEnd, by: 32) {
            v1 = Self.xxhRound(v1, input: Self.readLE64(memBuffer, offset: blockStart))
            v2 = Self.xxhRound(v2, input: Self.readLE64(memBuffer, offset: blockStart + 8))
            v3 = Self.xxhRound(v3, input: Self.readLE64(memBuffer, offset: blockStart + 16))
            v4 = Self.xxhRound(v4, input: Self.readLE64(memBuffer, offset: blockStart + 24))
        }

        memBuffer = Array(memBuffer.suffix(memBuffer.count - blocksEnd))
    }

    private static func xxhRound(_ acc: UInt64, input: UInt64) -> UInt64 {
        var a = acc &+ input &* p2
        a = rotl(a, 31)
        a &*= p1
        return a
    }

    private static func mergeRound(_ acc: UInt64, val: UInt64) -> UInt64 {
        let v = xxhRound(0, input: val)
        var a = acc ^ v
        a = a &* p1 &+ p4
        return a
    }

    private static func rotl(_ x: UInt64, _ r: Int) -> UInt64 {
        (x << r) | (x >> (64 - r))
    }

    // C-02 FIX: Bounds-checked reads
    private static func readLE64(_ buffer: [UInt8], offset: Int) -> UInt64 {
        guard offset >= 0, offset + 8 <= buffer.count else { return 0 }
        var value: UInt64 = 0
        for i in 0..<8 {
            value |= UInt64(buffer[offset + i]) << (i * 8)
        }
        return value
    }

    private static func readLE32(_ buffer: [UInt8], offset: Int) -> UInt32 {
        guard offset >= 0, offset + 4 <= buffer.count else { return 0 }
        var value: UInt32 = 0
        for i in 0..<4 {
            value |= UInt32(buffer[offset + i]) << (i * 8)
        }
        return value
    }
}
