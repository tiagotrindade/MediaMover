import XCTest
import Foundation
@testable import MediaMover

final class RenamePatternTests: XCTestCase {

    private let testDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 12
        components.hour = 14
        components.minute = 35
        components.second = 22
        components.nanosecond = 123_000_000
        return Calendar.current.date(from: components)!
    }()

    // MARK: - All Patterns

    func testDateOriginalPattern() {
        let result = RenamePattern.dateOriginal.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: "iPhone 15 Pro",
            sequenceNumber: 1
        )
        XCTAssertEqual(result, "20260312_143522123.jpg")
    }

    func testDateOriginalNamePattern() {
        let result = RenamePattern.dateOriginalName.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: "iPhone 15 Pro",
            sequenceNumber: 1
        )
        XCTAssertEqual(result, "20260312_143522123_IMG_4567.jpg")
    }

    func testDateCameraOriginalPattern() {
        let result = RenamePattern.dateCameraOriginal.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: "iPhone 15 Pro",
            sequenceNumber: 1
        )
        XCTAssertEqual(result, "20260312_143522123_iPhone15Pro_IMG_4567.jpg")
    }

    func testDateCameraPattern() {
        let result = RenamePattern.dateCamera.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: "iPhone 15 Pro",
            sequenceNumber: 1
        )
        XCTAssertEqual(result, "20260312_143522123_iPhone15Pro.jpg")
    }

    func testDateSeqPattern() {
        let result = RenamePattern.dateSeq.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: "iPhone 15 Pro",
            sequenceNumber: 42
        )
        XCTAssertEqual(result, "20260312_143522123_042.jpg")
    }

    func testDateOnlyPattern() {
        let result = RenamePattern.dateOnly.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertEqual(result, "20260312_143522.jpg")
    }

    func testYearMonthDayOriginalPattern() {
        let result = RenamePattern.yearMonthDayOriginal.rename(
            originalName: "IMG_4567.jpg",
            date: testDate,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertEqual(result, "2026-03-12_IMG_4567.jpg")
    }

    // MARK: - Edge Cases

    func testNilCameraUsesUnknown() {
        let result = RenamePattern.dateCamera.rename(
            originalName: "photo.jpg",
            date: testDate,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertTrue(result.contains("Unknown"))
    }

    func testCameraNameIsSanitized() {
        let result = RenamePattern.dateCameraOriginal.rename(
            originalName: "photo.jpg",
            date: testDate,
            camera: "Canon EOS R5",
            sequenceNumber: 1
        )
        XCTAssertTrue(result.contains("CanonEOSR5"))
    }

    func testExtensionIsPreservedAndLowercased() {
        let result = RenamePattern.dateOriginal.rename(
            originalName: "IMG_4567.HEIC",
            date: testDate,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertTrue(result.hasSuffix(".heic"))
    }

    func testFileWithoutExtension() {
        let result = RenamePattern.dateOriginal.rename(
            originalName: "README",
            date: testDate,
            camera: nil,
            sequenceNumber: 1
        )
        XCTAssertFalse(result.contains("."))
        XCTAssertEqual(result, "20260312_143522123")
    }

    // MARK: - Properties

    func testAllSevenPatternsExist() {
        XCTAssertEqual(RenamePattern.allCases.count, 7)
    }

    func testAllPatternsHaveDisplayNames() {
        for p in RenamePattern.allCases {
            XCTAssertFalse(p.displayName.isEmpty)
        }
    }

    func testAllPatternsHaveDescriptionExamples() {
        for p in RenamePattern.allCases {
            XCTAssertFalse(p.description.isEmpty)
            XCTAssertTrue(p.description.contains("2026"))
        }
    }

    func testIdentifiableConformance() {
        for p in RenamePattern.allCases {
            XCTAssertEqual(p.id, p.rawValue)
        }
    }
}
