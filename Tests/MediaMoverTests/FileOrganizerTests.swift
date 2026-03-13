import XCTest
import Foundation
@testable import MediaMover

final class FileOrganizerTests: XCTestCase {

    // MARK: - Copy Operation

    func testCopyFilesToFlatDateFolder() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let photoURL = sourceDir.appendingPathComponent("test_photo.jpg")
        try "photo data".data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(year: 2026, month: 3, day: 15)
        let file = MediaFile(
            url: photoURL, dateTaken: date, cameraModel: "TestCam",
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, records) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(records.count, 1)

        let expectedPath = destDir.appendingPathComponent("2026_03_15/test_photo.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoURL.path))
    }

    // MARK: - Move Operation

    func testMoveFilesRemovesFromSource() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let photoURL = sourceDir.appendingPathComponent("move_me.jpg")
        try "photo data".data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(year: 2025, month: 12, day: 1)
        let file = MediaFile(
            url: photoURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )

        let config = OrganizerConfig(
            mode: .move, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .skip,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoURL.path))
        let expectedPath = destDir.appendingPathComponent("2025_12_01/move_me.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    // MARK: - Video Subfolder

    func testVideosGoToSeparateSubfolder() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let videoURL = sourceDir.appendingPathComponent("clip.mov")
        try "video data".data(using: .utf8)!.write(to: videoURL)

        let date = makeDate(year: 2026, month: 1, day: 20)
        let file = MediaFile(
            url: videoURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .video
        )

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: true,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.processedFiles, 1)
        let expectedPath = destDir.appendingPathComponent("2026_01_20/Videos/clip.mov")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    // MARK: - Date Rename

    func testRenameWithDatePrefixAddsDateToFilename() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let photoURL = sourceDir.appendingPathComponent("sunset.jpg")
        try "photo".data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(year: 2026, month: 6, day: 15, hour: 10, minute: 30, second: 45)
        let file = MediaFile(
            url: photoURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 100, mediaType: .photo
        )

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: true, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.processedFiles, 1)
        let expectedPath = destDir.appendingPathComponent("2026_06_15/20260615_103045_sunset.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    // MARK: - Integrity Verification

    func testIntegrityVerificationWithSHA256() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let content = String(repeating: "A", count: 1024)
        let photoURL = sourceDir.appendingPathComponent("verified.jpg")
        try content.data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(year: 2026, month: 1, day: 1)
        let file = MediaFile(
            url: photoURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 1024, mediaType: .photo
        )

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: true, hashAlgorithm: .sha256,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertEqual(result.verifiedFiles, 1)
        XCTAssertEqual(result.verificationFailures, 0)
    }

    // MARK: - Duplicate Handling

    func testSkipDuplicateFiles() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let content = "same content"
        let photoURL = sourceDir.appendingPathComponent("dup.jpg")
        try content.data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(year: 2026, month: 2, day: 14)
        let file = MediaFile(
            url: photoURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: Int64(content.count), mediaType: .photo
        )

        let destSubDir = destDir.appendingPathComponent("2026_02_14")
        try FileManager.default.createDirectory(at: destSubDir, withIntermediateDirectories: true)
        try content.data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("dup.jpg"))

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .skip,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.skippedDuplicates, 1)
    }

    // MARK: - Progress Callback

    func testProgressCallbackFiresForEachFile() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        var files: [MediaFile] = []
        let date = makeDate(year: 2026, month: 1, day: 1)

        for i in 1...5 {
            let url = sourceDir.appendingPathComponent("file\(i).jpg")
            try "data".data(using: .utf8)!.write(to: url)
            files.append(MediaFile(
                url: url, dateTaken: date, cameraModel: nil,
                fileCreationDate: nil, fileModificationDate: Date(),
                fileSize: 4, mediaType: .photo
            ))
        }

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        var callbackCount = 0
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: files, destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { current, total, _ in
                callbackCount += 1
                XCTAssertEqual(total, 5)
                XCTAssertTrue(current >= 1 && current <= 5)
            }
        )

        XCTAssertEqual(result.processedFiles, 5)
        XCTAssertEqual(callbackCount, 5)
    }

    // MARK: - Multiple Folder Patterns

    func testNestedFolderPatternCreatesNestedFolders() async throws {
        let (sourceDir, destDir) = try createTestDirs()
        defer { cleanup(sourceDir, destDir) }

        let photoURL = sourceDir.appendingPathComponent("nested.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(year: 2026, month: 7, day: 4)
        let file = MediaFile(
            url: photoURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 4, mediaType: .photo
        )

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDay,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(
            files: [file], destination: destDir, config: config,
            duplicateResolver: nil, progressCallback: { _, _, _ in }
        )

        XCTAssertEqual(result.processedFiles, 1)
        let expectedPath = destDir.appendingPathComponent("2026/07/04/nested.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expectedPath.path))
    }

    // MARK: - Helpers

    private func createTestDirs() throws -> (URL, URL) {
        let base = FileManager.default.temporaryDirectory
        let source = base.appendingPathComponent("OrgTest_src_\(UUID().uuidString)")
        let dest = base.appendingPathComponent("OrgTest_dst_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
        return (source, dest)
    }

    private func cleanup(_ urls: URL...) {
        for url in urls {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 12, minute: Int = 0, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)!
    }
}
