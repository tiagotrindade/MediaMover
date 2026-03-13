import XCTest
import Foundation
@testable import MediaMover

// MARK: - Extended RenameViewModel Tests

@MainActor
final class RenameAllPatternPreviewTests: XCTestCase {

    func testDateOriginalPatternProducesDateOnlyFilename() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginal
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [makeFile("IMG_001.jpg", date: date, type: .photo)]
        vm.regeneratePreview()
        XCTAssertEqual(vm.previewItems.count, 1)
        XCTAssertTrue(vm.previewItems[0].newName.hasPrefix("20260312_143522"))
        XCTAssertFalse(vm.previewItems[0].newName.contains("IMG_001"))
    }

    func testDateCameraOriginalPatternIncludesCameraName() {
        let vm = RenameViewModel()
        vm.pattern = .dateCameraOriginal
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [makeFile("IMG_001.jpg", date: date, camera: "Canon EOS R5", type: .photo)]
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems[0].newName.contains("CanonEOSR5"))
        XCTAssertTrue(vm.previewItems[0].newName.contains("IMG_001"))
    }

    func testDateCameraPatternHasCameraButNotOriginalName() {
        let vm = RenameViewModel()
        vm.pattern = .dateCamera
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [makeFile("IMG_001.jpg", date: date, camera: "Sony A7IV", type: .photo)]
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems[0].newName.contains("SonyA7IV"))
        XCTAssertFalse(vm.previewItems[0].newName.contains("IMG_001"))
    }

    func testDateSeqPatternUsesSequenceNumber() {
        let vm = RenameViewModel()
        vm.pattern = .dateSeq
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [
            makeFile("a.jpg", date: date, type: .photo),
            makeFile("b.jpg", date: date, type: .photo),
            makeFile("c.jpg", date: date, type: .photo),
        ]
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems[0].newName.contains("_001."))
        XCTAssertTrue(vm.previewItems[1].newName.contains("_002."))
        XCTAssertTrue(vm.previewItems[2].newName.contains("_003."))
    }

    func testDateOnlyPatternHasNoMilliseconds() {
        let vm = RenameViewModel()
        vm.pattern = .dateOnly
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [makeFile("IMG.jpg", date: date, type: .photo)]
        vm.regeneratePreview()
        XCTAssertEqual(vm.previewItems[0].newName, "20260312_143522.jpg")
    }

    func testYearMonthDayOriginalPatternUsesDashes() {
        let vm = RenameViewModel()
        vm.pattern = .yearMonthDayOriginal
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [makeFile("IMG_001.jpg", date: date, type: .photo)]
        vm.regeneratePreview()
        XCTAssertEqual(vm.previewItems[0].newName, "2026-03-12_IMG_001.jpg")
    }
}

@MainActor
final class RenameViewModelEdgeCaseTests: XCTestCase {

    func testFileWithoutDateKeepsOriginalName() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginalName
        vm.dateFallback = .none
        vm.discoveredFiles = [makeFile("mystery.jpg", date: nil, creationDate: nil, type: .photo)]
        vm.regeneratePreview()
        XCTAssertEqual(vm.previewItems.count, 1)
        XCTAssertEqual(vm.previewItems[0].newName, "mystery.jpg")
    }

    func testFileWithCreationDateFallbackGetsRenamed() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginalName
        vm.dateFallback = .creationDate
        let creation = makeDate(2025, 12, 25, 10, 0, 0)
        vm.discoveredFiles = [makeFile("photo.jpg", date: nil, creationDate: creation, type: .photo)]
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems[0].newName.contains("20251225"))
    }

    func testEmptyDiscoveredFilesProducesEmptyPreview() {
        let vm = RenameViewModel()
        vm.discoveredFiles = []
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems.isEmpty)
    }

    func testMixedMediaAndOtherFilesInSameBatch() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginalName
        vm.includeOtherFiles = true
        let date = makeDate(2026, 6, 1, 12, 0, 0)

        vm.discoveredFiles = [
            makeFile("photo.jpg", date: date, type: .photo),
            makeFile("video.mov", date: date, type: .video),
            makeFile("doc.pdf", date: nil, creationDate: date, type: .other),
        ]
        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems.count, 3)
        XCTAssertTrue(vm.previewItems[0].newName.contains("photo"))
        XCTAssertTrue(vm.previewItems[1].newName.contains("video"))
        XCTAssertTrue(vm.previewItems[2].newName.contains("doc"))
        XCTAssertTrue(vm.previewItems[2].newName.contains("20260601"))
    }

    func testSequenceNumberSkipsOtherFiles() {
        let vm = RenameViewModel()
        vm.pattern = .dateSeq
        let date = makeDate(2026, 1, 1, 12, 0, 0)

        vm.discoveredFiles = [
            makeFile("a.jpg", date: date, type: .photo),
            makeFile("doc.pdf", date: nil, creationDate: date, type: .other),
            makeFile("b.jpg", date: date, type: .photo),
        ]
        vm.regeneratePreview()

        XCTAssertTrue(vm.previewItems[0].newName.contains("_001."))
        XCTAssertTrue(vm.previewItems[1].newName.contains("doc"))
        XCTAssertTrue(vm.previewItems[2].newName.contains("_002."))
    }

    func testRapidPatternSwitchDoesNotCrash() {
        let vm = RenameViewModel()
        let date = makeDate(2026, 3, 12, 14, 35, 22)
        vm.discoveredFiles = [makeFile("test.jpg", date: date, type: .photo)]

        for pattern in RenamePattern.allCases {
            vm.pattern = pattern
            vm.regeneratePreview()
            XCTAssertEqual(vm.previewItems.count, 1)
            XCTAssertFalse(vm.previewItems[0].newName.isEmpty)
        }
    }

    func testLargeBatchPreviewGeneration() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginalName
        let date = makeDate(2026, 3, 12, 14, 35, 22)

        var files: [MediaFile] = []
        for i in 0..<500 {
            files.append(makeFile("IMG_\(String(format: "%04d", i)).jpg", date: date, type: .photo))
        }
        vm.discoveredFiles = files
        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems.count, 500)
    }
}

@MainActor
final class RenameViewModelOtherFilesTests: XCTestCase {

    func testOtherFileWithNoDateKeepsOriginalName() {
        let vm = RenameViewModel()
        vm.dateFallback = .none
        vm.discoveredFiles = [makeFile("readme.txt", date: nil, creationDate: nil, type: .other)]
        vm.regeneratePreview()
        XCTAssertEqual(vm.previewItems[0].newName, "readme.txt")
    }

    func testOtherFileWithModificationDateGetsRenamed() {
        let vm = RenameViewModel()
        vm.dateFallback = .modificationDate
        let modDate = makeDate(2026, 4, 15, 9, 30, 0)
        vm.discoveredFiles = [
            MediaFile(
                url: URL(fileURLWithPath: "/tmp/report.xlsx"),
                dateTaken: nil, cameraModel: nil,
                fileCreationDate: nil, fileModificationDate: modDate,
                fileSize: 1024, mediaType: .other
            )
        ]
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems[0].newName.contains("20260415"))
        XCTAssertTrue(vm.previewItems[0].newName.contains("report"))
    }

    func testOtherFilePreservesExtension() {
        let vm = RenameViewModel()
        let date = makeDate(2026, 1, 1, 10, 0, 0)
        vm.discoveredFiles = [makeFile("archive.tar.gz", date: nil, creationDate: date, type: .other)]
        vm.regeneratePreview()
        XCTAssertTrue(vm.previewItems[0].newName.hasSuffix(".gz"))
    }
}

@MainActor
final class RenameViewModelSettingsTests: XCTestCase {

    func testDefaultSettingsAreCorrect() {
        let vm = RenameViewModel()
        XCTAssertEqual(vm.pattern, .dateOriginalName)
        XCTAssertTrue(vm.includePhotos)
        XCTAssertTrue(vm.includeVideos)
        XCTAssertFalse(vm.includeOtherFiles)
        XCTAssertTrue(vm.includeSubfolders)
        XCTAssertEqual(vm.dateFallback, .creationDate)
        XCTAssertEqual(vm.renameMode, .renameInPlace)
        XCTAssertNil(vm.sourceURL)
        XCTAssertNil(vm.destinationURL)
    }

    func testStateFlagsAreCorrectlyInitialized() {
        let vm = RenameViewModel()
        XCTAssertFalse(vm.isScanning)
        XCTAssertFalse(vm.isRenaming)
        XCTAssertEqual(vm.progress, 0)
        XCTAssertEqual(vm.currentFileIndex, 0)
        XCTAssertEqual(vm.totalFiles, 0)
        XCTAssertEqual(vm.currentFileName, "")
        XCTAssertTrue(vm.discoveredFiles.isEmpty)
        XCTAssertTrue(vm.previewItems.isEmpty)
        XCTAssertFalse(vm.renameComplete)
        XCTAssertEqual(vm.renamedCount, 0)
        XCTAssertEqual(vm.errorCount, 0)
    }

    func testFullResetClearsEverything() {
        let vm = RenameViewModel()
        vm.discoveredFiles = [makeFile("a.jpg", type: .photo)]
        vm.previewItems = [RenameViewModel.RenamePreview(originalName: "a.jpg", newName: "new.jpg", file: makeFile("a.jpg", type: .photo))]
        vm.renameComplete = true
        vm.renamedCount = 10
        vm.errorCount = 2
        vm.progress = 0.8

        vm.reset()

        XCTAssertTrue(vm.discoveredFiles.isEmpty)
        XCTAssertTrue(vm.previewItems.isEmpty)
        XCTAssertFalse(vm.renameComplete)
        XCTAssertEqual(vm.renamedCount, 0)
        XCTAssertEqual(vm.errorCount, 0)
        XCTAssertEqual(vm.progress, 0)
    }
}

@MainActor
final class RenameViewModelExecuteTests: XCTestCase {

    func testRenameInPlaceActuallyRenamesFiles() async throws {
        let vm = RenameViewModel()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("RenameTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("original.jpg")
        try "photo data".data(using: .utf8)!.write(to: fileURL)

        let date = makeDate(2026, 6, 15, 10, 30, 0)
        let file = MediaFile(
            url: fileURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 10, mediaType: .photo
        )

        vm.renameMode = .renameInPlace
        vm.pattern = .dateOriginalName
        vm.discoveredFiles = [file]
        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems.count, 1)
        XCTAssertNotEqual(vm.previewItems[0].newName, "original.jpg")

        await vm.executeRename()

        XCTAssertTrue(vm.renameComplete)
        XCTAssertEqual(vm.renamedCount, 1)
        XCTAssertEqual(vm.errorCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testRenameSkipsUnchangedFiles() async throws {
        let vm = RenameViewModel()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("RenameSkip_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let fileURL = dir.appendingPathComponent("nodatechange.jpg")
        try "data".data(using: .utf8)!.write(to: fileURL)

        let file = MediaFile(
            url: fileURL, dateTaken: nil, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 4, mediaType: .photo
        )

        vm.renameMode = .renameInPlace
        vm.dateFallback = .none
        vm.discoveredFiles = [file]
        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems[0].originalName, vm.previewItems[0].newName)

        await vm.executeRename()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertEqual(vm.renamedCount, 1)
    }

    func testCopyModeCreatesCopyAtDestination() async throws {
        let vm = RenameViewModel()
        let srcDir = FileManager.default.temporaryDirectory.appendingPathComponent("RenameCopySrc_\(UUID().uuidString)")
        let dstDir = FileManager.default.temporaryDirectory.appendingPathComponent("RenameCopyDst_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dstDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: srcDir)
            try? FileManager.default.removeItem(at: dstDir)
        }

        let fileURL = srcDir.appendingPathComponent("copy_me.jpg")
        try "copy data".data(using: .utf8)!.write(to: fileURL)

        let date = makeDate(2026, 1, 1, 12, 0, 0)
        let file = MediaFile(
            url: fileURL, dateTaken: date, cameraModel: nil,
            fileCreationDate: nil, fileModificationDate: Date(),
            fileSize: 9, mediaType: .photo
        )

        vm.renameMode = .copyToFolder
        vm.destinationURL = dstDir
        vm.pattern = .dateOriginalName
        vm.discoveredFiles = [file]
        vm.regeneratePreview()

        await vm.executeRename()

        XCTAssertTrue(vm.renameComplete)
        XCTAssertEqual(vm.renamedCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let destFiles = try FileManager.default.contentsOfDirectory(atPath: dstDir.path)
        XCTAssertEqual(destFiles.count, 1)
        XCTAssertTrue(destFiles[0].contains("copy_me"))
    }

    func testCollisionHandlingAppendsSuffix() async throws {
        let vm = RenameViewModel()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("RenameCollision_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let date = makeDate(2026, 3, 1, 12, 0, 0)

        let file1URL = dir.appendingPathComponent("first.jpg")
        let file2URL = dir.appendingPathComponent("second.jpg")
        try "data1".data(using: .utf8)!.write(to: file1URL)
        try "data2".data(using: .utf8)!.write(to: file2URL)

        vm.renameMode = .copyToFolder
        vm.destinationURL = dir.appendingPathComponent("output")
        try FileManager.default.createDirectory(at: vm.destinationURL!, withIntermediateDirectories: true)
        vm.pattern = .dateOnly

        vm.discoveredFiles = [
            MediaFile(url: file1URL, dateTaken: date, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 5, mediaType: .photo),
            MediaFile(url: file2URL, dateTaken: date, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 5, mediaType: .photo),
        ]
        vm.regeneratePreview()

        await vm.executeRename()

        XCTAssertEqual(vm.renamedCount, 2)
        XCTAssertEqual(vm.errorCount, 0)
    }
}

// MARK: - Helpers

private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Calendar.current.date(from: c)!
}

private func makeFile(
    _ name: String,
    date: Date? = nil,
    creationDate: Date? = nil,
    camera: String? = nil,
    type: MediaType
) -> MediaFile {
    MediaFile(
        url: URL(fileURLWithPath: "/tmp/\(name)"),
        dateTaken: date,
        cameraModel: camera,
        fileCreationDate: creationDate,
        fileModificationDate: Date(),
        fileSize: 1024,
        mediaType: type
    )
}
