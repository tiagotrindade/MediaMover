import XCTest
import Foundation
@testable import MediaMover

final class SupportedFormatsTests: XCTestCase {

    // MARK: - Photo Extensions

    func testStandardPhotoFormatsAreRecognized() {
        let formats = ["jpg", "jpeg", "png", "heic", "heif", "tiff", "tif"]
        for ext in formats {
            XCTAssertTrue(SupportedFormats.photoExtensions.contains(ext), "Missing photo format: \(ext)")
            XCTAssertEqual(SupportedFormats.mediaType(for: ext), .photo, "\(ext) should be .photo")
        }
    }

    func testRawPhotoFormatsAreRecognized() {
        let rawFormats = ["cr2", "cr3", "nef", "arw", "dng", "orf", "raf", "rw2", "pef", "srw", "x3f", "rwl", "mrw", "3fr", "fff", "iiq", "kdc", "dcr", "erf", "gpr"]
        for ext in rawFormats {
            XCTAssertTrue(SupportedFormats.photoExtensions.contains(ext), "Missing RAW photo format: \(ext)")
            XCTAssertEqual(SupportedFormats.mediaType(for: ext), .photo, "\(ext) should be .photo")
        }
    }

    // MARK: - Video Extensions

    func testStandardVideoFormatsAreRecognized() {
        let formats = ["mov", "mp4", "avi", "mkv", "m4v", "3gp", "wmv"]
        for ext in formats {
            XCTAssertTrue(SupportedFormats.videoExtensions.contains(ext), "Missing video format: \(ext)")
            XCTAssertEqual(SupportedFormats.mediaType(for: ext), .video, "\(ext) should be .video")
        }
    }

    func testRawVideoFormatsAreRecognized() {
        let rawFormats = ["braw", "r3d", "ari", "crm", "mxf", "mts", "m2ts"]
        for ext in rawFormats {
            XCTAssertTrue(SupportedFormats.videoExtensions.contains(ext), "Missing RAW video format: \(ext)")
            XCTAssertEqual(SupportedFormats.mediaType(for: ext), .video, "\(ext) should be .video")
        }
    }

    // MARK: - Edge Cases

    func testUnknownExtensionReturnsNil() {
        XCTAssertNil(SupportedFormats.mediaType(for: "xyz"))
        XCTAssertNil(SupportedFormats.mediaType(for: "pdf"))
        XCTAssertNil(SupportedFormats.mediaType(for: "docx"))
    }

    func testCaseInsensitiveLookup() {
        XCTAssertEqual(SupportedFormats.mediaType(for: "JPG"), .photo)
        XCTAssertEqual(SupportedFormats.mediaType(for: "Mov"), .video)
        XCTAssertEqual(SupportedFormats.mediaType(for: "HEIC"), .photo)
    }

    func testAllExtensionsIsUnionOfPhotoAndVideo() {
        let all = SupportedFormats.allExtensions
        XCTAssertEqual(all, SupportedFormats.photoExtensions.union(SupportedFormats.videoExtensions))
    }

    func testNoOverlapBetweenPhotoAndVideoExtensions() {
        let overlap = SupportedFormats.photoExtensions.intersection(SupportedFormats.videoExtensions)
        XCTAssertTrue(overlap.isEmpty, "Found overlap: \(overlap)")
    }
}
