import XCTest
import Foundation
@testable import MediaMover

// MARK: - OrganizerViewModel Tests

@MainActor
final class OrganizerViewModelDefaultTests: XCTestCase {

    func testDefaultSettingsMatchExpectedValues() {
        let vm = OrganizerViewModel()
        XCTAssertEqual(vm.pattern, .yearMonthDayFlat)
        XCTAssertEqual(vm.operationMode, .copy)
        XCTAssertTrue(vm.includePhotos)
        XCTAssertTrue(vm.includeVideos)
        XCTAssertFalse(vm.includeOtherFiles)
        XCTAssertTrue(vm.includeSubfolders)
        XCTAssertEqual(vm.dateFallback, .creationDate)
        XCTAssertTrue(vm.separateVideos)
        XCTAssertFalse(vm.renameWithDate)
        XCTAssertFalse(vm.separateByCamera)
        XCTAssertEqual(vm.duplicateStrategy, .ask)
        XCTAssertEqual(vm.duplicateAction, .rename)
        XCTAssertTrue(vm.verifyIntegrity)
        XCTAssertEqual(vm.hashAlgorithm, .xxhash64)
    }

    func testInitialStateFlagsAreCorrect() {
        let vm = OrganizerViewModel()
        XCTAssertFalse(vm.isScanning)
        XCTAssertFalse(vm.isProcessing)
        XCTAssertFalse(vm.isUndoing)
        XCTAssertEqual(vm.progress, 0)
        XCTAssertEqual(vm.currentFileIndex, 0)
        XCTAssertEqual(vm.totalFiles, 0)
        XCTAssertEqual(vm.currentFileName, "")
        XCTAssertTrue(vm.discoveredFiles.isEmpty)
        XCTAssertTrue(vm.previewItems.isEmpty)
        XCTAssertNil(vm.result)
        XCTAssertNil(vm.sourceURL)
        XCTAssertNil(vm.destinationURL)
    }
}

@MainActor
final class OrganizerViewModelPreviewTests: XCTestCase {

    func testPreviewFlatDatePattern() {
        let vm = OrganizerViewModel()
        vm.pattern = .yearMonthDayFlat
        vm.separateVideos = false
        vm.renameWithDate = false

        let date = makeDate(2026, 7, 4, 15, 30, 0)
        vm.discoveredFiles = [makeFile("photo.jpg", date: date, type: .photo)]
        vm.generatePreview()

        XCTAssertEqual(vm.previewItems.count, 1)
        XCTAssertEqual(vm.previewItems[0].destinationSubpath, "2026_07_04")
        XCTAssertEqual(vm.previewItems[0].fileName, "photo.jpg")
    }

    func testPreviewAddsVideosSubfolderForVideoFiles() {
        let vm = OrganizerViewModel()
        vm.separateVideos = true
        let date = makeDate(2026, 3, 15)
        vm.discoveredFiles = [makeFile("clip.mov", date: date, type: .video)]
        vm.generatePreview()

        XCTAssertEqual(vm.previewItems[0].destinationSubpath, "2026_03_15/Videos")
    }

    func testPreviewAddsCameraSubfolderWhenEnabled() {
        let vm = OrganizerViewModel()
        vm.separateByCamera = true
        vm.separateVideos = false
        let date = makeDate(2026, 3, 15)
        vm.discoveredFiles = [makeFile("photo.jpg", date: date, camera: "iPhone 15 Pro", type: .photo)]
        vm.generatePreview()

        XCTAssertTrue(vm.previewItems[0].destinationSubpath.contains("iPhone"))
    }

    func testPreviewAddsDatePrefixToFilenameWhenRenameWithDateEnabled() {
        let vm = OrganizerViewModel()
        vm.renameWithDate = true
        vm.separateVideos = false
        let date = makeDate(2026, 6, 15, 10, 30, 45)
        vm.discoveredFiles = [makeFile("sunset.jpg", date: date, type: .photo)]
        vm.generatePreview()

        XCTAssertTrue(vm.previewItems[0].fileName.contains("20260615"))
        XCTAssertTrue(vm.previewItems[0].fileName.contains("sunset.jpg"))
    }

    func testPreviewShowsNoDateForFilesWithoutDateWhenFallbackIsNone() {
        let vm = OrganizerViewModel()
        vm.dateFallback = .none
        vm.discoveredFiles = [
            MediaFile(
                url: URL(fileURLWithPath: "/tmp/nodate.jpg"),
                dateTaken: nil, cameraModel: nil,
                fileCreationDate: nil, fileModificationDate: Date(),
                fileSize: 100, mediaType: .photo
            )
        ]
        vm.generatePreview()

        XCTAssertEqual(vm.previewItems[0].destinationSubpath, "No Date")
    }

    func testPreviewHandlesMixedMediaTypes() {
        let vm = OrganizerViewModel()
        vm.separateVideos = true
        let date = makeDate(2026, 3, 15)
        vm.discoveredFiles = [
            makeFile("photo.jpg", date: date, type: .photo),
            makeFile("video.mov", date: date, type: .video),
            makeFile("doc.pdf", date: date, type: .other),
        ]
        vm.generatePreview()

        XCTAssertEqual(vm.previewItems.count, 3)
        XCTAssertFalse(vm.previewItems[0].destinationSubpath.contains("Videos"))
        XCTAssertTrue(vm.previewItems[1].destinationSubpath.contains("Videos"))
        XCTAssertFalse(vm.previewItems[2].destinationSubpath.contains("Videos"))
    }

    func testPreviewRegeneratesOnPatternChange() {
        let vm = OrganizerViewModel()
        let date = makeDate(2026, 3, 15)
        vm.discoveredFiles = [makeFile("test.jpg", date: date, type: .photo)]

        vm.pattern = .yearMonthDayFlat
        vm.generatePreview()
        let flat = vm.previewItems[0].destinationSubpath

        vm.pattern = .yearMonthDay
        vm.generatePreview()
        let nested = vm.previewItems[0].destinationSubpath

        XCTAssertEqual(flat, "2026_03_15")
        XCTAssertEqual(nested, "2026/03/15")
    }

    func testPreviewVideoAndCameraSubfolderCombined() {
        let vm = OrganizerViewModel()
        vm.separateVideos = true
        vm.separateByCamera = true
        let date = makeDate(2026, 3, 15)
        vm.discoveredFiles = [makeFile("clip.mov", date: date, camera: "DJI Mini 3", type: .video)]
        vm.generatePreview()

        let subpath = vm.previewItems[0].destinationSubpath
        XCTAssertTrue(subpath.contains("DJI"))
        XCTAssertTrue(subpath.contains("Videos"))
    }
}

@MainActor
final class OrganizerViewModelResetTests: XCTestCase {

    func testResetClearsAllState() {
        let vm = OrganizerViewModel()
        vm.discoveredFiles = [makeFile("a.jpg", type: .photo)]
        vm.previewItems = [OrganizerViewModel.MoverPreview(fileName: "a.jpg", destinationSubpath: "2026_01_01", mediaType: .photo)]
        vm.result = OperationResult(totalFiles: 5)
        vm.progress = 0.5
        vm.currentFileIndex = 3
        vm.currentFileName = "test.jpg"

        vm.reset()

        XCTAssertNil(vm.result)
        XCTAssertTrue(vm.discoveredFiles.isEmpty)
        XCTAssertTrue(vm.previewItems.isEmpty)
        XCTAssertEqual(vm.progress, 0)
        XCTAssertEqual(vm.currentFileIndex, 0)
        XCTAssertEqual(vm.currentFileName, "")
    }
}

@MainActor
final class OrganizerViewModelDuplicateTests: XCTestCase {

    func testDuplicateDialogInitialState() {
        let vm = OrganizerViewModel()
        XCTAssertFalse(vm.showDuplicateDialog)
        XCTAssertEqual(vm.duplicateSourceName, "")
        XCTAssertEqual(vm.duplicateSourceSize, 0)
        XCTAssertEqual(vm.duplicateExistingName, "")
        XCTAssertEqual(vm.duplicateExistingSize, 0)
        XCTAssertFalse(vm.applyDuplicateToAll)
    }

    func testResolveDuplicateClosesDialog() {
        let vm = OrganizerViewModel()
        vm.showDuplicateDialog = true
        vm.resolveDuplicate(action: .rename)
        XCTAssertFalse(vm.showDuplicateDialog)
    }
}

// MARK: - Helpers

private func makeDate(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0, _ s: Int = 0) -> Date {
    var c = DateComponents()
    c.year = y; c.month = m; c.day = d; c.hour = h; c.minute = mi; c.second = s
    return Calendar.current.date(from: c)!
}

private func makeFile(_ name: String, date: Date? = nil, camera: String? = nil, type: MediaType) -> MediaFile {
    MediaFile(
        url: URL(fileURLWithPath: "/tmp/\(name)"),
        dateTaken: date,
        cameraModel: camera,
        fileCreationDate: nil,
        fileModificationDate: Date(),
        fileSize: 1024,
        mediaType: type
    )
}
