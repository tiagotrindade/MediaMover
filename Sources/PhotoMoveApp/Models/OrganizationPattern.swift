import Foundation

enum OrganizationPattern: String, CaseIterable, Identifiable, Sendable {
    case yearMonthDay
    case yearMonth
    case yearMonthDayFlat
    case yearMonthDayCamera
    case yearMonthCamera
    case cameraYearMonthDay
    case yearOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .yearMonthDay:        return "YYYY / MM / DD"
        case .yearMonth:           return "YYYY / MM"
        case .yearMonthDayFlat:    return "YYYY_MM_DD"
        case .yearMonthDayCamera:  return "YYYY / MM / DD / Camera"
        case .yearMonthCamera:     return "YYYY / MM / Camera"
        case .cameraYearMonthDay:  return "Camera / YYYY / MM / DD"
        case .yearOnly:            return "YYYY"
        }
    }

    func examplePath(camera: String = "iPhone 15") -> String {
        destinationSubpath(for: Date(), camera: camera)
    }

    func destinationSubpath(for date: Date, camera: String?) -> String {
        let cal = Calendar.current
        let year = String(format: "%04d", cal.component(.year, from: date))
        let month = String(format: "%02d", cal.component(.month, from: date))
        let day = String(format: "%02d", cal.component(.day, from: date))
        let cam = sanitizeFolderName(camera ?? "Unknown Camera")

        switch self {
        case .yearMonthDay:
            return "\(year)/\(month)/\(day)"
        case .yearMonth:
            return "\(year)/\(month)"
        case .yearMonthDayFlat:
            return "\(year)_\(month)_\(day)"
        case .yearMonthDayCamera:
            return "\(year)/\(month)/\(day)/\(cam)"
        case .yearMonthCamera:
            return "\(year)/\(month)/\(cam)"
        case .cameraYearMonthDay:
            return "\(cam)/\(year)/\(month)/\(day)"
        case .yearOnly:
            return year
        }
    }

    private func sanitizeFolderName(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal).joined(separator: "_").trimmingCharacters(in: .whitespaces)
    }
}
