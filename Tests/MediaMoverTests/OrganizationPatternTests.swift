import XCTest
import Foundation
@testable import MediaMover

final class OrganizationPatternTests: XCTestCase {

    private let testDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 3
        components.day = 15
        return Calendar.current.date(from: components)!
    }()

    // MARK: - Destination Subpath Generation

    func testYearMonthDayPattern() {
        let result = OrganizationPattern.yearMonthDay.destinationSubpath(for: testDate, camera: nil)
        XCTAssertEqual(result, "2026/03/15")
    }

    func testYearMonthPattern() {
        let result = OrganizationPattern.yearMonth.destinationSubpath(for: testDate, camera: nil)
        XCTAssertEqual(result, "2026/03")
    }

    func testYearMonthDayFlatPattern() {
        let result = OrganizationPattern.yearMonthDayFlat.destinationSubpath(for: testDate, camera: nil)
        XCTAssertEqual(result, "2026_03_15")
    }

    func testYearMonthDayCameraPattern() {
        let result = OrganizationPattern.yearMonthDayCamera.destinationSubpath(for: testDate, camera: "iPhone 15 Pro")
        XCTAssertEqual(result, "2026/03/15/iPhone 15 Pro")
    }

    func testYearMonthCameraPattern() {
        let result = OrganizationPattern.yearMonthCamera.destinationSubpath(for: testDate, camera: "Canon EOS R5")
        XCTAssertEqual(result, "2026/03/Canon EOS R5")
    }

    func testCameraYearMonthDayPattern() {
        let result = OrganizationPattern.cameraYearMonthDay.destinationSubpath(for: testDate, camera: "Sony A7IV")
        XCTAssertEqual(result, "Sony A7IV/2026/03/15")
    }

    func testYearOnlyPattern() {
        let result = OrganizationPattern.yearOnly.destinationSubpath(for: testDate, camera: nil)
        XCTAssertEqual(result, "2026")
    }

    // MARK: - Nil Camera Handling

    func testNilCameraFallback() {
        let result = OrganizationPattern.yearMonthDayCamera.destinationSubpath(for: testDate, camera: nil)
        XCTAssertEqual(result, "2026/03/15/Unknown Camera")
    }

    // MARK: - All Cases & Properties

    func testAllSevenPatternsExist() {
        XCTAssertEqual(OrganizationPattern.allCases.count, 7)
    }

    func testAllPatternsHaveDisplayNames() {
        for pattern in OrganizationPattern.allCases {
            XCTAssertFalse(pattern.displayName.isEmpty)
        }
    }

    func testExamplePathGeneratesNonEmptyString() {
        for pattern in OrganizationPattern.allCases {
            XCTAssertFalse(pattern.examplePath().isEmpty)
        }
    }

    // MARK: - Identifiable Conformance

    func testIdentifiableIdIsRawValue() {
        for pattern in OrganizationPattern.allCases {
            XCTAssertEqual(pattern.id, pattern.rawValue)
        }
    }
}
