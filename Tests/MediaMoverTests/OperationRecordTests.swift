import XCTest
import Foundation
@testable import MediaMover

// MARK: - OperationRecord & BatchOperation Tests

final class FileOperationRecordTests: XCTestCase {

    func testRecordStoresAllFieldsCorrectly() {
        let now = Date()
        let record = FileOperationRecord(
            action: .copy,
            sourcePath: "/Users/test/source/photo.jpg",
            destinationPath: "/Users/test/dest/2026_03_15/photo.jpg",
            timestamp: now
        )

        XCTAssertEqual(record.action, .copy)
        XCTAssertEqual(record.sourcePath, "/Users/test/source/photo.jpg")
        XCTAssertEqual(record.destinationPath, "/Users/test/dest/2026_03_15/photo.jpg")
        XCTAssertEqual(record.timestamp, now)
    }

    func testRecordIsCodable() throws {
        let record = FileOperationRecord(
            action: .move,
            sourcePath: "/tmp/source.jpg",
            destinationPath: "/tmp/dest.jpg",
            timestamp: Date()
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(FileOperationRecord.self, from: data)

        XCTAssertEqual(decoded.action, record.action)
        XCTAssertEqual(decoded.sourcePath, record.sourcePath)
        XCTAssertEqual(decoded.destinationPath, record.destinationPath)
    }
}

final class BatchOperationTests: XCTestCase {

    func testBatchInitializesWithCorrectValues() {
        let records = [
            FileOperationRecord(action: .copy, sourcePath: "/a", destinationPath: "/b", timestamp: Date()),
            FileOperationRecord(action: .copy, sourcePath: "/c", destinationPath: "/d", timestamp: Date()),
        ]

        let batch = BatchOperation(mode: .copy, records: records)

        XCTAssertEqual(batch.mode, .copy)
        XCTAssertEqual(batch.fileCount, 2)
        XCTAssertEqual(batch.records.count, 2)
    }

    func testBatchIsCodable() throws {
        let records = [
            FileOperationRecord(action: .move, sourcePath: "/a", destinationPath: "/b", timestamp: Date()),
        ]
        let batch = BatchOperation(mode: .move, records: records)

        let data = try JSONEncoder().encode(batch)
        let decoded = try JSONDecoder().decode(BatchOperation.self, from: data)

        XCTAssertEqual(decoded.mode, .move)
        XCTAssertEqual(decoded.fileCount, 1)
        XCTAssertEqual(decoded.records.count, 1)
    }

    func testBatchHasUniqueId() {
        let b1 = BatchOperation(mode: .copy, records: [])
        let b2 = BatchOperation(mode: .copy, records: [])
        XCTAssertNotEqual(b1.id, b2.id)
    }

    func testEmptyBatchHasZeroFileCount() {
        let batch = BatchOperation(mode: .copy, records: [])
        XCTAssertEqual(batch.fileCount, 0)
        XCTAssertTrue(batch.records.isEmpty)
    }
}

final class OperationModeTests: XCTestCase {

    func testBothModesExist() {
        XCTAssertEqual(OperationMode.allCases.count, 2)
        XCTAssertTrue(OperationMode.allCases.contains(.copy))
        XCTAssertTrue(OperationMode.allCases.contains(.move))
    }

    func testRawValuesAreCorrect() {
        XCTAssertEqual(OperationMode.copy.rawValue, "Copy")
        XCTAssertEqual(OperationMode.move.rawValue, "Move")
    }

    func testOperationModeIsCodable() throws {
        let data = try JSONEncoder().encode(OperationMode.move)
        let decoded = try JSONDecoder().decode(OperationMode.self, from: data)
        XCTAssertEqual(decoded, .move)
    }
}

final class DuplicateStrategyTests: XCTestCase {

    func testAllStrategiesExist() {
        XCTAssertEqual(DuplicateStrategy.allCases.count, 3)
    }

    func testRawValuesAreDescriptive() {
        XCTAssertEqual(DuplicateStrategy.ask.rawValue, "Ask Each Time")
        XCTAssertEqual(DuplicateStrategy.automatic.rawValue, "Automatic")
        XCTAssertEqual(DuplicateStrategy.skip.rawValue, "Don't Move")
    }
}

final class DuplicateActionTests: XCTestCase {

    func testAllActionsExist() {
        XCTAssertEqual(DuplicateAction.allCases.count, 3)
    }

    func testRawValuesAreDescriptive() {
        XCTAssertEqual(DuplicateAction.rename.rawValue, "Rename File")
        XCTAssertEqual(DuplicateAction.overwrite.rawValue, "Replace")
        XCTAssertEqual(DuplicateAction.overwriteIfLarger.rawValue, "Replace if Larger")
    }
}

// MARK: - OperationResult Tests

final class OperationResultTests: XCTestCase {

    func testDefaultValuesAreZero() {
        let result = OperationResult()
        XCTAssertEqual(result.totalFiles, 0)
        XCTAssertEqual(result.processedFiles, 0)
        XCTAssertEqual(result.skippedDuplicates, 0)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.elapsedTime, 0)
        XCTAssertEqual(result.verifiedFiles, 0)
        XCTAssertEqual(result.verificationFailures, 0)
        XCTAssertTrue(result.verificationErrors.isEmpty)
    }

    func testSuccessCountCalculatesCorrectly() {
        var result = OperationResult(totalFiles: 10)
        result.processedFiles = 8
        result.errors = [(file: "bad1.jpg", error: "error1"), (file: "bad2.jpg", error: "error2")]
        XCTAssertEqual(result.successCount, 6)
    }

    func testSuccessCountWithZeroErrors() {
        var result = OperationResult(totalFiles: 5)
        result.processedFiles = 5
        XCTAssertEqual(result.successCount, 5)
    }

    func testOperationResultIsIdentifiable() {
        let r1 = OperationResult()
        let r2 = OperationResult()
        XCTAssertNotEqual(r1.id, r2.id)
    }
}

// MARK: - OrganizerConfig Tests

final class OrganizerConfigTests: XCTestCase {

    func testConfigStoresAllProperties() {
        let config = OrganizerConfig(
            mode: .move,
            pattern: .yearMonthDay,
            duplicateStrategy: .automatic,
            duplicateAction: .overwrite,
            verifyIntegrity: true,
            hashAlgorithm: .sha256,
            dateFallback: .modificationDate,
            separateVideos: true,
            renameWithDate: true,
            separateByCamera: true
        )

        XCTAssertEqual(config.mode, .move)
        XCTAssertEqual(config.pattern, .yearMonthDay)
        XCTAssertEqual(config.duplicateStrategy, .automatic)
        XCTAssertEqual(config.duplicateAction, .overwrite)
        XCTAssertTrue(config.verifyIntegrity)
        XCTAssertEqual(config.hashAlgorithm, .sha256)
        XCTAssertEqual(config.dateFallback, .modificationDate)
        XCTAssertTrue(config.separateVideos)
        XCTAssertTrue(config.renameWithDate)
        XCTAssertTrue(config.separateByCamera)
    }
}
