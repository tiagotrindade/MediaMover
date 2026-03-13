import XCTest
import Foundation
@testable import MediaMover

final class RenameModeTests: XCTestCase {

    func testBothRenameModesExist() {
        XCTAssertEqual(RenameMode.allCases.count, 2)
    }

    func testRawValuesAreDescriptive() {
        XCTAssertEqual(RenameMode.renameInPlace.rawValue, "Rename in place")
        XCTAssertEqual(RenameMode.copyToFolder.rawValue, "Copy to folder")
    }
}

@MainActor
final class RenameViewModelPreviewTests: XCTestCase {

    func testRegeneratePreviewForMediaFiles() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginalName

        let date = makeDate(year: 2026, month: 3, day: 12, hour: 14, minute: 35, second: 22)
        vm.discoveredFiles = [
            makeMediaFile(name: "IMG_001.jpg", dateTaken: date, mediaType: .photo),
            makeMediaFile(name: "clip.mov", dateTaken: date, mediaType: .video),
        ]

        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems.count, 2)
        XCTAssertTrue(vm.previewItems[0].newName.contains("20260312"))
        XCTAssertTrue(vm.previewItems[0].newName.contains("IMG_001"))
        XCTAssertTrue(vm.previewItems[1].newName.contains("clip"))
    }

    func testRegeneratePreviewHandlesOtherFilesWithDatePrefix() {
        let vm = RenameViewModel()
        vm.pattern = .dateOriginalName
        vm.includeOtherFiles = true

        let date = makeDate(year: 2026, month: 1, day: 5, hour: 10, minute: 0, second: 0)
        vm.discoveredFiles = [
            makeMediaFile(name: "document.pdf", dateTaken: nil, creation: date, mediaType: .other),
        ]

        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems.count, 1)
        XCTAssertTrue(vm.previewItems[0].newName.contains("20260105"))
        XCTAssertTrue(vm.previewItems[0].newName.contains("document"))
    }

    func testRegeneratePreviewKeepsOriginalNameForOtherFilesWithoutDate() {
        let vm = RenameViewModel()
        vm.dateFallback = .none

        vm.discoveredFiles = [
            makeMediaFile(name: "mystery.pdf", dateTaken: nil, creation: nil, mediaType: .other),
        ]

        vm.regeneratePreview()

        XCTAssertEqual(vm.previewItems.count, 1)
        XCTAssertEqual(vm.previewItems[0].newName, "mystery.pdf")
    }

    func testPatternChangeRegeneratesPreview() {
        let vm = RenameViewModel()
        let date = makeDate(year: 2026, month: 3, day: 12, hour: 14, minute: 35, second: 22)
        vm.discoveredFiles = [
            makeMediaFile(name: "photo.jpg", dateTaken: date, mediaType: .photo),
        ]

        vm.pattern = .dateOriginal
        vm.regeneratePreview()
        let name1 = vm.previewItems.first?.newName

        vm.pattern = .yearMonthDayOriginal
        vm.regeneratePreview()
        let name2 = vm.previewItems.first?.newName

        XCTAssertNotEqual(name1, name2)
        XCTAssertEqual(name1?.contains("143522"), true)
        XCTAssertEqual(name2?.contains("2026-03-12"), true)
    }

    func testResetClearsAllState() {
        let vm = RenameViewModel()
        vm.discoveredFiles = [makeMediaFile(name: "a.jpg", mediaType: .photo)]
        vm.previewItems = [RenameViewModel.RenamePreview(
            originalName: "a.jpg", newName: "new.jpg",
            file: makeMediaFile(name: "a.jpg", mediaType: .photo)
        )]
        vm.renameComplete = true
        vm.renamedCount = 5
        vm.errorCount = 2
        vm.progress = 0.75

        vm.reset()

        XCTAssertTrue(vm.discoveredFiles.isEmpty)
        XCTAssertTrue(vm.previewItems.isEmpty)
        XCTAssertFalse(vm.renameComplete)
        XCTAssertEqual(vm.renamedCount, 0)
        XCTAssertEqual(vm.errorCount, 0)
        XCTAssertEqual(vm.progress, 0)
    }

    // MARK: - Helpers

    private func makeMediaFile(
        name: String,
        dateTaken: Date? = nil,
        creation: Date? = nil,
        mediaType: MediaType
    ) -> MediaFile {
        MediaFile(
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            dateTaken: dateTaken,
            cameraModel: nil,
            fileCreationDate: creation,
            fileModificationDate: Date(),
            fileSize: 1024,
            mediaType: mediaType
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0, second: Int = 0) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute; c.second = second
        return Calendar.current.date(from: c)!
    }
}
