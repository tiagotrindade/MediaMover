import XCTest
import Foundation
@testable import MediaMover

// MARK: - Extended FileOrganizer Tests

final class FileOrganizerCameraTests: XCTestCase {

    func testCameraSubfolderCreatesCameraNamedDirectory() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("photo.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 3, 15), camera: "Canon EOS R5", type: .photo)

        let config = makeConfig(separateByCamera: true)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let expected = dst.appendingPathComponent("2026_03_15/Canon_EOS_R5/photo.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func testCameraSubfolderWithSpecialCharactersInCameraName() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("photo.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 1, 1), camera: "Sony \u{03B1}7R IV", type: .photo)

        let config = makeConfig(separateByCamera: true)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(result.errors.isEmpty)
    }

    func testCameraAndVideoSubfolderCombined() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let videoURL = src.appendingPathComponent("clip.mov")
        try "data".data(using: .utf8)!.write(to: videoURL)

        let file = makeMediaFile(url: videoURL, date: makeDate(2026, 6, 20), camera: "iPhone 15 Pro", type: .video)

        let config = makeConfig(separateVideos: true, separateByCamera: true)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let expected = dst.appendingPathComponent("2026_06_20/iPhone_15_Pro/Videos/clip.mov")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func testNilCameraNoSubfolderWhenSeparateByCameraEnabled() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("photo.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 3, 15), camera: nil, type: .photo)

        let config = makeConfig(separateByCamera: true)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let expected = dst.appendingPathComponent("2026_03_15/photo.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }
}

final class FileOrganizerDateFallbackTests: XCTestCase {

    func testSkipFilesWithNoDateWhenFallbackIsNone() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("nodate.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let file = MediaFile(
            url: photoURL, dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 4, mediaType: .photo
        )

        let config = makeConfig(dateFallback: .none)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertEqual(result.skippedDuplicates, 1)
    }

    func testCreationDateFallbackWhenNoEXIFDate() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("fallback.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let creationDate = makeDate(2025, 12, 25)
        let file = MediaFile(
            url: photoURL, dateTaken: nil, cameraModel: nil,
            fileCreationDate: creationDate, fileModificationDate: Date(),
            fileSize: 4, mediaType: .photo
        )

        let config = makeConfig(dateFallback: .creationDate)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let expected = dst.appendingPathComponent("2025_12_25/fallback.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }

    func testModificationDateFallbackWhenNoEXIFDate() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("modfall.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let modDate = makeDate(2024, 7, 4)
        let file = MediaFile(
            url: photoURL, dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: modDate,
            fileSize: 4, mediaType: .photo
        )

        let config = makeConfig(dateFallback: .modificationDate)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let expected = dst.appendingPathComponent("2024_07_04/modfall.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
    }
}

final class FileOrganizerDuplicateExtendedTests: XCTestCase {

    func testRenameDuplicateAppendsSuffix() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("dup.jpg")
        try "source content".data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(2026, 2, 14)
        let file = makeMediaFile(url: photoURL, date: date, type: .photo, size: 14)

        let destSubDir = dst.appendingPathComponent("2026_02_14")
        try FileManager.default.createDirectory(at: destSubDir, withIntermediateDirectories: true)
        try "existing".data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("dup.jpg"))

        let config = makeConfig(duplicateStrategy: .automatic, duplicateAction: .rename)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let renamed = dst.appendingPathComponent("2026_02_14/dup_1.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }

    func testOverwriteReplacesExistingFile() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("replace.jpg")
        try "new content that is longer".data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(2026, 5, 1)
        let file = makeMediaFile(url: photoURL, date: date, type: .photo, size: 26)

        let destSubDir = dst.appendingPathComponent("2026_05_01")
        try FileManager.default.createDirectory(at: destSubDir, withIntermediateDirectories: true)
        try "old".data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("replace.jpg"))

        let config = makeConfig(duplicateStrategy: .automatic, duplicateAction: .overwrite)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let destFile = dst.appendingPathComponent("2026_05_01/replace.jpg")
        let content = try String(contentsOf: destFile, encoding: .utf8)
        XCTAssertEqual(content, "new content that is longer")
    }

    func testOverwriteIfLargerSkipsWhenExistingIsSameSize() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let content = "same size content"
        let photoURL = src.appendingPathComponent("samesize.jpg")
        try content.data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(2026, 8, 15)
        let file = makeMediaFile(url: photoURL, date: date, type: .photo, size: Int64(content.count))

        let destSubDir = dst.appendingPathComponent("2026_08_15")
        try FileManager.default.createDirectory(at: destSubDir, withIntermediateDirectories: true)
        try "same size content plus extra".data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("samesize.jpg"))

        let config = makeConfig(duplicateStrategy: .automatic, duplicateAction: .overwriteIfLarger)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.skippedDuplicates, 1)
    }

    func testOverwriteIfLargerReplacesWhenSourceIsLarger() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let bigContent = String(repeating: "X", count: 1000)
        let photoURL = src.appendingPathComponent("bigger.jpg")
        try bigContent.data(using: .utf8)!.write(to: photoURL)

        let date = makeDate(2026, 8, 15)
        let file = makeMediaFile(url: photoURL, date: date, type: .photo, size: Int64(bigContent.count))

        let destSubDir = dst.appendingPathComponent("2026_08_15")
        try FileManager.default.createDirectory(at: destSubDir, withIntermediateDirectories: true)
        try "tiny".data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("bigger.jpg"))

        let config = makeConfig(duplicateStrategy: .automatic, duplicateAction: .overwriteIfLarger)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertEqual(result.skippedDuplicates, 0)
        let destContent = try String(contentsOf: dst.appendingPathComponent("2026_08_15/bigger.jpg"), encoding: .utf8)
        XCTAssertEqual(destContent.count, 1000)
    }

    func testMultipleDuplicateRenamesProduceSequentialSuffixes() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let date = makeDate(2026, 1, 1)
        let destSubDir = dst.appendingPathComponent("2026_01_01")
        try FileManager.default.createDirectory(at: destSubDir, withIntermediateDirectories: true)
        try "existing0".data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("dup.jpg"))
        try "existing1".data(using: .utf8)!.write(to: destSubDir.appendingPathComponent("dup_1.jpg"))

        let photoURL = src.appendingPathComponent("dup.jpg")
        try "source".data(using: .utf8)!.write(to: photoURL)
        let file = makeMediaFile(url: photoURL, date: date, type: .photo)

        let config = makeConfig(duplicateStrategy: .automatic, duplicateAction: .rename)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        let renamed = dst.appendingPathComponent("2026_01_01/dup_2.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: renamed.path))
    }
}

final class FileOrganizerAllPatternTests: XCTestCase {

    func testYearMonthDayPatternCreatesNestedFolders() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("a.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)
        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 11, 30), type: .photo)

        let config = makeConfig(pattern: .yearMonthDay)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026/11/30/a.jpg").path))
    }

    func testYearMonthPatternCreatesYearMonthFolders() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("b.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)
        let file = makeMediaFile(url: photoURL, date: makeDate(2025, 6, 15), type: .photo)

        let config = makeConfig(pattern: .yearMonth)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2025/06/b.jpg").path))
    }

    func testYearOnlyPatternCreatesYearFolder() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("c.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)
        let file = makeMediaFile(url: photoURL, date: makeDate(2024, 1, 1), type: .photo)

        let config = makeConfig(pattern: .yearOnly)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2024/c.jpg").path))
    }

    func testYearMonthDayCameraPatternCreatesCameraFolder() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("d.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)
        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 4, 10), camera: "Nikon Z8", type: .photo)

        let config = makeConfig(pattern: .yearMonthDayCamera)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026/04/10/Nikon Z8/d.jpg").path))
    }

    func testCameraYearMonthDayPatternCreatesCameraFirstFolder() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("e.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)
        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 9, 1), camera: "Sony A7IV", type: .photo)

        let config = makeConfig(pattern: .cameraYearMonthDay)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("Sony A7IV/2026/09/01/e.jpg").path))
    }
}

final class FileOrganizerIntegrityExtendedTests: XCTestCase {

    func testXXHashVerificationSucceeds() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let content = String(repeating: "B", count: 2048)
        let photoURL = src.appendingPathComponent("verified.jpg")
        try content.data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 1, 1), type: .photo, size: 2048)

        let config = makeConfig(verifyIntegrity: true, hashAlgorithm: .xxhash64)
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.verifiedFiles, 1)
        XCTAssertEqual(result.verificationFailures, 0)
    }

    func testMoveVerificationReadsDestinationOnly() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("movecheck.jpg")
        try "move data".data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 2, 2), type: .photo)

        let config = OrganizerConfig(
            mode: .move, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: true, hashAlgorithm: .sha256,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertEqual(result.verifiedFiles, 1)
    }
}

final class FileOrganizerMixedMediaTests: XCTestCase {

    func testProcessBatchOfPhotosAndVideosWithVideoSubfolder() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let date = makeDate(2026, 3, 12)
        var files: [MediaFile] = []

        for i in 1...3 {
            let url = src.appendingPathComponent("photo\(i).jpg")
            try "photo".data(using: .utf8)!.write(to: url)
            files.append(makeMediaFile(url: url, date: date, type: .photo))
        }
        for i in 1...2 {
            let url = src.appendingPathComponent("video\(i).mov")
            try "video".data(using: .utf8)!.write(to: url)
            files.append(makeMediaFile(url: url, date: date, type: .video))
        }

        let config = makeConfig(separateVideos: true)
        let organizer = FileOrganizer()
        let (result, records) = await organizer.organize(files: files, destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 5)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(records.count, 5)

        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026_03_12/photo1.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026_03_12/Videos/video1.mov").path))
    }

    func testProcessFilesFromMultipleDates() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        var files: [MediaFile] = []
        let dates = [makeDate(2026, 1, 1), makeDate(2026, 6, 15), makeDate(2026, 12, 31)]

        for (i, date) in dates.enumerated() {
            let url = src.appendingPathComponent("img\(i).jpg")
            try "data".data(using: .utf8)!.write(to: url)
            files.append(makeMediaFile(url: url, date: date, type: .photo))
        }

        let config = makeConfig()
        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: files, destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026_01_01/img0.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026_06_15/img1.jpg").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: dst.appendingPathComponent("2026_12_31/img2.jpg").path))
    }

    func testEmptyFileListReturnsZeroCounts() async throws {
        let (_, dst) = try createTestDirs()
        defer { cleanup(dst) }

        let config = makeConfig()
        let organizer = FileOrganizer()
        let (result, records) = await organizer.organize(files: [], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.totalFiles, 0)
        XCTAssertEqual(result.processedFiles, 0)
        XCTAssertTrue(records.isEmpty)
    }
}

final class FileOrganizerComboTests: XCTestCase {

    func testDateRenameCameraSubfolderVideoSubfolderAllAtOnce() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let videoURL = src.appendingPathComponent("clip.mov")
        try "video data".data(using: .utf8)!.write(to: videoURL)

        let date = makeDate(2026, 7, 4, 15, 30, 45)
        let file = makeMediaFile(url: videoURL, date: date, camera: "DJI Mavic 3", type: .video)

        let config = OrganizerConfig(
            mode: .copy, pattern: .yearMonthDay,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: true, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: true,
            renameWithDate: true, separateByCamera: true
        )

        let organizer = FileOrganizer()
        let (result, _) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(result.processedFiles, 1)
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertEqual(result.verifiedFiles, 1)
    }
}

final class FileOrganizerRecordTests: XCTestCase {

    func testRecordsContainCorrectSourceAndDestinationPaths() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("recorded.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 3, 15), type: .photo)
        let config = makeConfig()
        let organizer = FileOrganizer()
        let (_, records) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].sourcePath, photoURL.path)
        XCTAssertTrue(records[0].destinationPath.contains("2026_03_15/recorded.jpg"))
        XCTAssertEqual(records[0].action, .copy)
    }

    func testMoveRecordsHaveCorrectActionType() async throws {
        let (src, dst) = try createTestDirs()
        defer { cleanup(src, dst) }

        let photoURL = src.appendingPathComponent("moved.jpg")
        try "data".data(using: .utf8)!.write(to: photoURL)

        let file = makeMediaFile(url: photoURL, date: makeDate(2026, 1, 1), type: .photo)
        let config = OrganizerConfig(
            mode: .move, pattern: .yearMonthDayFlat,
            duplicateStrategy: .automatic, duplicateAction: .rename,
            verifyIntegrity: false, hashAlgorithm: .xxhash64,
            dateFallback: .creationDate, separateVideos: false,
            renameWithDate: false, separateByCamera: false
        )
        let organizer = FileOrganizer()
        let (_, records) = await organizer.organize(files: [file], destination: dst, config: config, progressCallback: { _, _, _ in })

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].action, .move)
    }
}

// MARK: - Shared Test Helpers

private func createTestDirs() throws -> (URL, URL) {
    let base = FileManager.default.temporaryDirectory
    let source = base.appendingPathComponent("ExtTest_src_\(UUID().uuidString)")
    let dest = base.appendingPathComponent("ExtTest_dst_\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
    return (source, dest)
}

private func cleanup(_ urls: URL...) {
    for url in urls { try? FileManager.default.removeItem(at: url) }
}

private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Calendar.current.date(from: c)!
}

private func makeMediaFile(url: URL, date: Date, camera: String? = nil, type: MediaType, size: Int64 = 4) -> MediaFile {
    MediaFile(url: url, dateTaken: date, cameraModel: camera, fileCreationDate: nil, fileModificationDate: Date(), fileSize: size, mediaType: type)
}

private func makeConfig(
    mode: OperationMode = .copy,
    pattern: OrganizationPattern = .yearMonthDayFlat,
    duplicateStrategy: DuplicateStrategy = .automatic,
    duplicateAction: DuplicateAction = .rename,
    verifyIntegrity: Bool = false,
    hashAlgorithm: HashAlgorithm = .xxhash64,
    dateFallback: DateFallback = .creationDate,
    separateVideos: Bool = false,
    renameWithDate: Bool = false,
    separateByCamera: Bool = false
) -> OrganizerConfig {
    OrganizerConfig(
        mode: mode, pattern: pattern,
        duplicateStrategy: duplicateStrategy, duplicateAction: duplicateAction,
        verifyIntegrity: verifyIntegrity, hashAlgorithm: hashAlgorithm,
        dateFallback: dateFallback, separateVideos: separateVideos,
        renameWithDate: renameWithDate, separateByCamera: separateByCamera
    )
}
