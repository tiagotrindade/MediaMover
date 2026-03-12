import Foundation
import CryptoKit

// MARK: - Hash Algorithm Selection

enum HashAlgorithm: String, CaseIterable, Sendable {
    case xxhash64 = "XXHash64 (Fast)"
    case sha256 = "SHA-256 (Secure)"
}

// MARK: - File Hashing Service

struct FileHashing: Sendable {

    static func hash(of url: URL, algorithm: HashAlgorithm) throws -> String {
        switch algorithm {
        case .xxhash64:
            return try xxhash64(of: url)
        case .sha256:
            return try sha256(of: url)
        }
    }

    static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }

        var hasher = SHA256()
        let chunkSize = 1024 * 1024 // 1 MB

        while true {
            let data = handle.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func xxhash64(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }

        var hasher = XXHash64Hasher()
        let chunkSize = 4 * 1024 * 1024 // 4 MB chunks for speed

        while true {
            let data = handle.readData(ofLength: chunkSize)
            if data.isEmpty { break }
            hasher.update(data: data)
        }

        return hasher.finalizeHex()
    }
}
