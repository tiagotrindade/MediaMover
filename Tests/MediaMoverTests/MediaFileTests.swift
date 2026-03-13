import XCTest
@testable import MediaMover

final class MediaFileTests: XCTestCase {

    private let now = Date()
    private let yesterday = Date(timeIntervalSinceNow: -86400)
    private let lastWeek = Date(timeIntervalSinceNow: -604800)

    // MARK: - Initialization

    func testInitFileName() {
        let file = makeFile(name: "IMG_001.jpg")
        XCTAssertEqual(file.fileName, "IMG_001.jpg")
        XCTAssertEqual(file.fileExtension, "jpg")
    }

    func testPhotoTypeDetection() {
        let file = makeFile(name: "photo.heic")
        XCTAssertEqual(file.mediaType, .photo)
    }

    func testVideoTypeDetection() {
        let file = makeFile(name: "video.mov")
        XCTAssertEqual(file.mediaType, .video)
    }

    func testExplicitMediaType() {
        let url = URL(fileURLWithPath: "/tmp/test.xyz")
        let file = MediaFile(url: url, dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: now, fileSize: 100, mediaType: .other)
        XCTAssertEqual(file.mediaType, .other)
    }

    // MARK: - effectiveDate

    func testEffectiveDateTaken() {
        let file = makeFile(name: "a.jpg", dateTaken: lastWeek, creation: yesterday, mod: now)
        XCTAssertEqual(file.effectiveDate(), lastWeek)
    }

    func testEffectiveDateCreationFallback() {
        let file = makeFile(name: "a.jpg", dateTaken: nil, creation: yesterday, mod: now)
        XCTAssertEqual(file.effectiveDate(fallback: .creationDate), yesterday)
    }

    func testEffectiveDateModFallback() {
        let file = makeFile(name: "a.jpg", dateTaken: nil, creation: yesterday, mod: now)
        XCTAssertEqual(file.effectiveDate(fallback: .modificationDate), now)
    }

    func testEffectiveDateNoneFallback() {
        let file = makeFile(name: "a.jpg", dateTaken: nil, creation: yesterday, mod: now)
        XCTAssertNil(file.effectiveDate(fallback: .none))
    }

    func testEffectiveDateCreationFallsToMod() {
        let file = makeFile(name: "a.jpg", dateTaken: nil, creation: nil, mod: now)
        XCTAssertEqual(file.effectiveDate(fallback: .creationDate), now)
    }

    func testEffectiveDatePriority() {
        let file = makeFile(name: "a.jpg", dateTaken: lastWeek, creation: yesterday, mod: now)
        for fallback in DateFallback.allCases {
            XCTAssertEqual(file.effectiveDate(fallback: fallback), lastWeek)
        }
    }

    // MARK: - Identifiable

    func testUniqueIds() {
        let f1 = makeFile(name: "a.jpg")
        let f2 = makeFile(name: "b.jpg")
        XCTAssertNotEqual(f1.id, f2.id)
    }

    // MARK: - Edge cases

    func testZeroSizeFile() {
        let file = MediaFile(url: URL(fileURLWithPath: "/tmp/empty.jpg"), dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 0, mediaType: .photo)
        XCTAssertEqual(file.fileSize, 0)
    }

    func testVeryLargeFileSize() {
        let file = MediaFile(url: URL(fileURLWithPath: "/tmp/huge.mov"), dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 50_000_000_000, mediaType: .video)
        XCTAssertEqual(file.fileSize, 50_000_000_000)
    }

    func testAutoDetectsMediaType() {
        let jpg = MediaFile(url: URL(fileURLWithPath: "/tmp/test.jpg"), dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 100)
        XCTAssertEqual(jpg.mediaType, .photo)
        let mov = MediaFile(url: URL(fileURLWithPath: "/tmp/test.mov"), dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 100)
        XCTAssertEqual(mov.mediaType, .video)
    }

    func testUnicodeFilename() {
        let file = MediaFile(url: URL(fileURLWithPath: "/tmp/фото_пляж.jpg"), dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 100, mediaType: .photo)
        XCTAssertEqual(file.fileName, "фото_пляж.jpg")
    }

    func testMultipleDotsFilename() {
        let file = MediaFile(url: URL(fileURLWithPath: "/tmp/photo.2026.03.15.jpg"), dateTaken: nil, cameraModel: nil, fileCreationDate: nil, fileModificationDate: Date(), fileSize: 100, mediaType: .photo)
        XCTAssertEqual(file.fileExtension, "jpg")
    }

    // MARK: - Helpers

    private func makeFile(name: String, dateTaken: Date? = nil, creation: Date? = nil, mod: Date = Date(), camera: String? = nil) -> MediaFile {
        MediaFile(url: URL(fileURLWithPath: "/tmp/\(name)"), dateTaken: dateTaken, cameraModel: camera, fileCreationDate: creation, fileModificationDate: mod, fileSize: 1024)
    }
}

final class DateFallbackTests: XCTestCase {
    func testAllCases() { XCTAssertEqual(DateFallback.allCases.count, 3) }
    func testRawValues() {
        XCTAssertTrue(DateFallback.creationDate.rawValue.contains("Creation"))
        XCTAssertTrue(DateFallback.modificationDate.rawValue.contains("Modification"))
        XCTAssertTrue(DateFallback.none.rawValue.contains("Skip"))
    }
}

final class MediaTypeTests: XCTestCase {
    func testAllCases() {
        XCTAssertEqual(MediaType.allCases.count, 3)
        XCTAssertTrue(MediaType.allCases.contains(.photo))
        XCTAssertTrue(MediaType.allCases.contains(.video))
        XCTAssertTrue(MediaType.allCases.contains(.other))
    }
}
