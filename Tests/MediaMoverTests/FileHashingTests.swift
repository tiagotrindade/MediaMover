import XCTest
import Foundation
@testable import MediaMover

final class FileHashingTests: XCTestCase {

    // MARK: - SHA256

    func testSHA256ConsistentHashForSameContent() throws {
        let (file1, file2) = try createTwoIdenticalFiles()
        defer { cleanup(file1, file2) }

        let hash1 = try FileHashing.sha256(of: file1)
        let hash2 = try FileHashing.sha256(of: file2)
        XCTAssertEqual(hash1, hash2)
    }

    func testSHA256DifferentHashForDifferentContent() throws {
        let file1 = try createTempFile(content: "Hello, World!")
        let file2 = try createTempFile(content: "Hello, World!!")
        defer { cleanup(file1, file2) }

        let hash1 = try FileHashing.sha256(of: file1)
        let hash2 = try FileHashing.sha256(of: file2)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testSHA256HashIs64HexCharacters() throws {
        let file = try createTempFile(content: "test")
        defer { cleanup(file) }

        let hash = try FileHashing.sha256(of: file)
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    // MARK: - XXHash64

    func testXXHash64ConsistentHashForSameContent() throws {
        let (file1, file2) = try createTwoIdenticalFiles()
        defer { cleanup(file1, file2) }

        let hash1 = try FileHashing.xxhash64(of: file1)
        let hash2 = try FileHashing.xxhash64(of: file2)
        XCTAssertEqual(hash1, hash2)
    }

    func testXXHash64DifferentHashForDifferentContent() throws {
        let file1 = try createTempFile(content: "Alpha")
        let file2 = try createTempFile(content: "Beta")
        defer { cleanup(file1, file2) }

        let hash1 = try FileHashing.xxhash64(of: file1)
        let hash2 = try FileHashing.xxhash64(of: file2)
        XCTAssertNotEqual(hash1, hash2)
    }

    func testXXHash64HashIs16HexCharacters() throws {
        let file = try createTempFile(content: "test")
        defer { cleanup(file) }

        let hash = try FileHashing.xxhash64(of: file)
        XCTAssertEqual(hash.count, 16)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    // MARK: - Algorithm Dispatch

    func testAlgorithmDispatchToCorrectAlgorithm() throws {
        let file = try createTempFile(content: "dispatch test")
        defer { cleanup(file) }

        let sha = try FileHashing.hash(of: file, algorithm: .sha256)
        let xx = try FileHashing.hash(of: file, algorithm: .xxhash64)

        XCTAssertEqual(sha.count, 64)
        XCTAssertEqual(xx.count, 16)
        XCTAssertNotEqual(sha, xx)
    }

    // MARK: - Large File

    func testHashingWorksWithLargeFile() throws {
        let data = Data(repeating: 0x42, count: 2 * 1024 * 1024)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("large_\(UUID().uuidString).bin")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let sha = try FileHashing.sha256(of: url)
        let xx = try FileHashing.xxhash64(of: url)

        XCTAssertEqual(sha.count, 64)
        XCTAssertEqual(xx.count, 16)
    }

    // MARK: - Empty File

    func testHashingEmptyFileProducesValidHash() throws {
        let file = try createTempFile(content: "")
        defer { cleanup(file) }

        let sha = try FileHashing.sha256(of: file)
        let xx = try FileHashing.xxhash64(of: file)

        XCTAssertEqual(sha.count, 64)
        XCTAssertEqual(xx.count, 16)
    }

    // MARK: - Helpers

    private func createTempFile(content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hash_test_\(UUID().uuidString).txt")
        try content.data(using: .utf8)!.write(to: url)
        return url
    }

    private func createTwoIdenticalFiles() throws -> (URL, URL) {
        let content = "identical content for hashing"
        return (try createTempFile(content: content), try createTempFile(content: content))
    }

    private func cleanup(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

final class HashAlgorithmTests: XCTestCase {

    func testBothAlgorithmsExist() {
        XCTAssertEqual(HashAlgorithm.allCases.count, 2)
    }

    func testRawValuesAreHumanReadable() {
        XCTAssertTrue(HashAlgorithm.xxhash64.rawValue.contains("Fast"))
        XCTAssertTrue(HashAlgorithm.sha256.rawValue.contains("Secure"))
    }
}
