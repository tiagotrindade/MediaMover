import XCTest
import Foundation
@testable import MediaMover

// MARK: - Edge Case & Stress Tests

final class FilenameEdgeCaseTests: XCTestCase {

    func testUnicodeFilenameIsHandledCorrectly() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/\u{0444}\u{043E}\u{0442}\u{043E}_\u{043F}\u{043B}\u{044F}\u{0436}.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )
        XCTAssertEqual(file.fileName, "\u{0444}\u{043E}\u{0442}\u{043E}_\u{043F}\u{043B}\u{044F}\u{0436}.jpg")
        XCTAssertEqual(file.fileExtension, "jpg")
    }

    func testCJKCharactersInFilename() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/\u{5199}\u{771F}_2026.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )
        XCTAssertEqual(file.fileName, "\u{5199}\u{771F}_2026.jpg")
    }

    func testEmojiInFilename() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/\u{1F4F8}_vacation.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )
        XCTAssertTrue(file.fileName.contains("\u{1F4F8}"))
    }

    func testSpacesInFilename() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/my photo from vacation.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )
        XCTAssertTrue(file.fileName.contains(" "))
    }

    func testMultipleDotsInFilename() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/photo.2026.03.15.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )
        XCTAssertEqual(file.fileExtension, "jpg")
    }

    func testRenamePatternHandlesFileWithoutExtension() {
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        let result = RenamePattern.dateOriginalName.rename(
            originalName: "DCIM_0001",
            date: date,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertFalse(result.contains("."))
        XCTAssertTrue(result.contains("DCIM_0001"))
    }

    func testRenamePatternHandlesEmptyCameraNameGracefully() {
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        let result = RenamePattern.dateCameraOriginal.rename(
            originalName: "photo.jpg",
            date: date,
            camera: "",
            sequenceNumber: 1
        )
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.hasSuffix(".jpg"))
    }

    func testRenamePatternHandlesVeryLongFilename() {
        let date = makeDate(2026, 1, 1, 0, 0, 0)
        let longName = String(repeating: "A", count: 200) + ".jpg"
        let result = RenamePattern.dateOriginalName.rename(
            originalName: longName,
            date: date,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertTrue(result.contains(String(repeating: "A", count: 200)))
        XCTAssertTrue(result.hasSuffix(".jpg"))
    }
}

final class OrganizationPatternEdgeCaseTests: XCTestCase {

    func testCameraNameWithSlashesIsSanitized() {
        let date = makeDate(2026, 3, 15)
        let result = OrganizationPattern.yearMonthDayCamera.destinationSubpath(
            for: date, camera: "Canon/EOS R5"
        )
        XCTAssertFalse(result.components(separatedBy: "/").last!.contains("/"))
    }

    func testCameraNameWithSpecialCharsIsSanitized() {
        let date = makeDate(2026, 3, 15)
        let result = OrganizationPattern.cameraYearMonthDay.destinationSubpath(
            for: date, camera: "My:Camera*Name?"
        )
        XCTAssertFalse(result.contains(":"))
        XCTAssertFalse(result.contains("*"))
        XCTAssertFalse(result.contains("?"))
    }

    func testAllPatternsProduceValidPathsForEveryMonth() {
        for month in 1...12 {
            let date = makeDate(2026, month, 15)
            for pattern in OrganizationPattern.allCases {
                let subpath = pattern.destinationSubpath(for: date, camera: "TestCam")
                XCTAssertFalse(subpath.isEmpty, "Pattern \(pattern) failed for month \(month)")
                XCTAssertFalse(subpath.hasPrefix("/"), "Subpath should not start with /")
            }
        }
    }

    func testLeapYearDateWorksCorrectly() {
        let date = makeDate(2024, 2, 29)
        let result = OrganizationPattern.yearMonthDayFlat.destinationSubpath(for: date, camera: nil)
        XCTAssertEqual(result, "2024_02_29")
    }

    func testNewYearsEveDate() {
        let date = makeDate(2026, 12, 31)
        let result = OrganizationPattern.yearMonthDay.destinationSubpath(for: date, camera: nil)
        XCTAssertEqual(result, "2026/12/31")
    }
}

final class MediaFileEdgeCaseTests: XCTestCase {

    func testEffectiveDateWithAllDatesNilAndNoneFallback() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 0, mediaType: .photo
        )
        XCTAssertNil(file.effectiveDate(fallback: .none))
    }

    func testZeroSizeFileIsValid() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/empty.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 0, mediaType: .photo
        )
        XCTAssertEqual(file.fileSize, 0)
    }

    func testVeryLargeFileSize() {
        let file = MediaFile(
            url: URL(fileURLWithPath: "/tmp/huge.mov"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 50_000_000_000,
            mediaType: .video
        )
        XCTAssertEqual(file.fileSize, 50_000_000_000)
    }

    func testAutoDetectsMediaTypeFromExtension() {
        let jpg = MediaFile(
            url: URL(fileURLWithPath: "/tmp/test.jpg"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100
        )
        XCTAssertEqual(jpg.mediaType, .photo)

        let mov = MediaFile(
            url: URL(fileURLWithPath: "/tmp/test.mov"),
            dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100
        )
        XCTAssertEqual(mov.mediaType, .video)
    }
}

final class FileEnumeratorEdgeCaseTests: XCTestCase {

    func testNonExistentDirectoryReturnsEmpty() {
        let url = URL(fileURLWithPath: "/tmp/definitely_does_not_exist_\(UUID().uuidString)")
        let results = FileEnumerator.enumerateMedia(in: url, includePhotos: true, includeVideos: true)
        XCTAssertTrue(results.isEmpty)
    }

    func testOnlyOtherFilesSelectedWithIncludeSubfoldersFalse() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("EnumEdge_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "data".data(using: .utf8)!.write(to: dir.appendingPathComponent("doc.pdf"))
        try "data".data(using: .utf8)!.write(to: dir.appendingPathComponent("photo.jpg"))

        let sub = dir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try "data".data(using: .utf8)!.write(to: sub.appendingPathComponent("subdoc.txt"))

        let results = FileEnumerator.enumerateMedia(
            in: dir, includePhotos: false, includeVideos: false,
            includeOtherFiles: true, includeSubfolders: false
        )
        let names = Set(results.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("doc.pdf"))
        XCTAssertFalse(names.contains("subdoc.txt"))
        XCTAssertFalse(names.contains("photo.jpg"))
    }

    func testAllThreeTypesSelectedEnumeratesEverything() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("EnumAll_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        try "data".data(using: .utf8)!.write(to: dir.appendingPathComponent("photo.jpg"))
        try "data".data(using: .utf8)!.write(to: dir.appendingPathComponent("video.mov"))
        try "data".data(using: .utf8)!.write(to: dir.appendingPathComponent("doc.pdf"))

        let results = FileEnumerator.enumerateMedia(
            in: dir, includePhotos: true, includeVideos: true,
            includeOtherFiles: true, includeSubfolders: true
        )
        XCTAssertEqual(results.count, 3)
    }

    func testDeeplyNestedSubfolderStructure() throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("DeepEnum_\(UUID().uuidString)")
        var current = base
        try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        for i in 0..<5 {
            current = current.appendingPathComponent("level\(i)")
            try FileManager.default.createDirectory(at: current, withIntermediateDirectories: true)
        }
        try "data".data(using: .utf8)!.write(to: current.appendingPathComponent("deep_photo.jpg"))

        let results = FileEnumerator.enumerateMedia(
            in: base, includePhotos: true, includeVideos: false, includeSubfolders: true
        )
        let names = results.map { $0.lastPathComponent }
        XCTAssertTrue(names.contains("deep_photo.jpg"))
    }
}

final class FileHashingEdgeCaseTests: XCTestCase {

    func testHashingSingleByteFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("single_\(UUID().uuidString).bin")
        try Data([0x42]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let sha = try FileHashing.sha256(of: url)
        let xx = try FileHashing.xxhash64(of: url)
        XCTAssertEqual(sha.count, 64)
        XCTAssertEqual(xx.count, 16)
    }

    func testHashingProducesReproducibleResults() throws {
        let content = "The quick brown fox jumps over the lazy dog"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("repro_\(UUID().uuidString).txt")
        try content.data(using: .utf8)!.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let hash1 = try FileHashing.sha256(of: url)
        let hash2 = try FileHashing.sha256(of: url)
        let hash3 = try FileHashing.sha256(of: url)
        XCTAssertEqual(hash1, hash2)
        XCTAssertEqual(hash2, hash3)
    }
}

final class SupportedFormatsExtendedTests: XCTestCase {

    func testAllCanonRAWFormatsRecognized() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "cr2"), .photo)
        XCTAssertEqual(SupportedFormats.mediaType(for: "cr3"), .photo)
        XCTAssertEqual(SupportedFormats.mediaType(for: "crm"), .video)
    }

    func testAllNikonRAWFormatsRecognized() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "nef"), .photo)
    }

    func testAllSonyRAWFormatsRecognized() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "arw"), .photo)
    }

    func testDNGFormatRecognized() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "dng"), .photo)
    }

    func testHEICHEIFFormatsRecognized() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "heic"), .photo)
        XCTAssertEqual(SupportedFormats.mediaType(for: "heif"), .photo)
    }

    func testCommonDocumentFormatsAreNotMedia() {
        XCTAssertNil(SupportedFormats.mediaType(for: "pdf"))
        XCTAssertNil(SupportedFormats.mediaType(for: "docx"))
        XCTAssertNil(SupportedFormats.mediaType(for: "xlsx"))
        XCTAssertNil(SupportedFormats.mediaType(for: "txt"))
        XCTAssertNil(SupportedFormats.mediaType(for: "html"))
        XCTAssertNil(SupportedFormats.mediaType(for: "zip"))
    }

    func testProfessionalVideoFormatsRecognized() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "braw"), .video)
        XCTAssertEqual(SupportedFormats.mediaType(for: "r3d"), .video)
        XCTAssertEqual(SupportedFormats.mediaType(for: "mxf"), .video)
    }
}

// MARK: - Helpers

private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Calendar.current.date(from: c)!
}
