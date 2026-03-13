import XCTest
import Foundation
@testable import MediaMover

final class FileEnumeratorTests: XCTestCase {

    private var testDir: URL!

    override func setUp() throws {
        try super.setUp()

        // Create a temporary directory structure for testing
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("MediaMoverTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        // Create test files
        try createFile(at: base.appendingPathComponent("photo1.jpg"))
        try createFile(at: base.appendingPathComponent("photo2.heic"))
        try createFile(at: base.appendingPathComponent("video1.mov"))
        try createFile(at: base.appendingPathComponent("video2.mp4"))
        try createFile(at: base.appendingPathComponent("document.pdf"))
        try createFile(at: base.appendingPathComponent("readme.txt"))
        try createFile(at: base.appendingPathComponent(".hidden_file.jpg")) // hidden

        // Create subfolder with files
        let subDir = base.appendingPathComponent("subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try createFile(at: subDir.appendingPathComponent("sub_photo.cr2"))
        try createFile(at: subDir.appendingPathComponent("sub_video.mkv"))
        try createFile(at: subDir.appendingPathComponent("sub_doc.docx"))

        testDir = base
    }

    override func tearDown() {
        if let testDir = testDir {
            try? FileManager.default.removeItem(at: testDir)
        }
        super.tearDown()
    }

    // MARK: - Basic Enumeration

    func testEnumeratePhotosOnly() {
        let urls = FileEnumerator.enumerateMedia(in: testDir, includePhotos: true, includeVideos: false)
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("photo1.jpg"))
        XCTAssertTrue(names.contains("photo2.heic"))
        XCTAssertTrue(names.contains("sub_photo.cr2"))
        XCTAssertFalse(names.contains("video1.mov"))
        XCTAssertFalse(names.contains("document.pdf"))
    }

    func testEnumerateVideosOnly() {
        let urls = FileEnumerator.enumerateMedia(in: testDir, includePhotos: false, includeVideos: true)
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("video1.mov"))
        XCTAssertTrue(names.contains("video2.mp4"))
        XCTAssertTrue(names.contains("sub_video.mkv"))
        XCTAssertFalse(names.contains("photo1.jpg"))
    }

    func testEnumeratePhotosAndVideos() {
        let urls = FileEnumerator.enumerateMedia(in: testDir, includePhotos: true, includeVideos: true)
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("photo1.jpg"))
        XCTAssertTrue(names.contains("video1.mov"))
        XCTAssertFalse(names.contains("document.pdf"))
    }

    func testEnumerateNothingReturnsEmpty() {
        let urls = FileEnumerator.enumerateMedia(in: testDir, includePhotos: false, includeVideos: false)
        XCTAssertTrue(urls.isEmpty)
    }

    // MARK: - Other Files

    func testIncludeOtherFiles() {
        let urls = FileEnumerator.enumerateMedia(
            in: testDir, includePhotos: false, includeVideos: false, includeOtherFiles: true
        )
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("document.pdf"))
        XCTAssertTrue(names.contains("readme.txt"))
        XCTAssertTrue(names.contains("sub_doc.docx"))
        XCTAssertFalse(names.contains("photo1.jpg"))
        XCTAssertFalse(names.contains("video1.mov"))
    }

    func testOtherFilesAlongsidePhotos() {
        let urls = FileEnumerator.enumerateMedia(
            in: testDir, includePhotos: true, includeVideos: false, includeOtherFiles: true
        )
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("photo1.jpg"))
        XCTAssertTrue(names.contains("document.pdf"))
        XCTAssertFalse(names.contains("video1.mov"))
    }

    // MARK: - Subfolder Inclusion

    func testExcludeSubfoldersOnlyTopLevel() {
        let urls = FileEnumerator.enumerateMedia(
            in: testDir, includePhotos: true, includeVideos: true, includeSubfolders: false
        )
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("photo1.jpg"))
        XCTAssertTrue(names.contains("video1.mov"))
        XCTAssertFalse(names.contains("sub_photo.cr2"), "Subfolder files should be excluded")
        XCTAssertFalse(names.contains("sub_video.mkv"), "Subfolder files should be excluded")
    }

    func testIncludeSubfoldersAllFiles() {
        let urls = FileEnumerator.enumerateMedia(
            in: testDir, includePhotos: true, includeVideos: true, includeSubfolders: true
        )
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertTrue(names.contains("photo1.jpg"))
        XCTAssertTrue(names.contains("sub_photo.cr2"))
        XCTAssertTrue(names.contains("sub_video.mkv"))
    }

    // MARK: - Hidden Files

    func testHiddenFilesAreSkipped() {
        let urls = FileEnumerator.enumerateMedia(in: testDir, includePhotos: true, includeVideos: true)
        let names = Set(urls.map { $0.lastPathComponent })
        XCTAssertFalse(names.contains(".hidden_file.jpg"), "Hidden files should be skipped")
    }

    // MARK: - Results Sorted

    func testResultsAreSortedByFilename() {
        let urls = FileEnumerator.enumerateMedia(in: testDir, includePhotos: true, includeVideos: true)
        let names = urls.map { $0.lastPathComponent }
        XCTAssertEqual(names, names.sorted())
    }

    // MARK: - Empty Directory

    func testEmptyDirectoryReturnsEmptyArray() throws {
        let emptyDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("EmptyTestDir_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: emptyDir) }

        let urls = FileEnumerator.enumerateMedia(in: emptyDir, includePhotos: true, includeVideos: true)
        XCTAssertTrue(urls.isEmpty)
    }

    // MARK: - Helpers

    private func createFile(at url: URL) throws {
        try "test content".data(using: .utf8)!.write(to: url)
    }
}
