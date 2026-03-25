import Foundation

/// Naming patterns for mass rename.
enum RenamePattern: String, CaseIterable, Identifiable, Sendable {
    case dateOriginal        // 20260312_143522123.jpg
    case dateOriginalName    // 20260312_143522123_IMG_4567.jpg
    case dateCameraOriginal  // 20260312_143522123_iPhone15Pro_IMG_4567.jpg
    case dateCamera          // 20260312_143522123_iPhone15Pro.jpg
    case dateSeq             // 20260312_143522123_001.jpg
    case dateOnly            // 20260312_143522.jpg  (no ms)
    case yearMonthDayOriginal // 2026-03-12_IMG_4567.jpg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateOriginal:        return "Date_Original"
        case .dateOriginalName:    return "Date_OriginalName"
        case .dateCameraOriginal:  return "Date_Camera_Original"
        case .dateCamera:          return "Date_Camera"
        case .dateSeq:             return "Date_Sequence"
        case .dateOnly:            return "Date Only"
        case .yearMonthDayOriginal: return "YYYY-MM-DD_Original"
        }
    }

    var description: String {
        switch self {
        case .dateOriginal:        return "20260312_143522123.jpg"
        case .dateOriginalName:    return "20260312_143522123_IMG_4567.jpg"
        case .dateCameraOriginal:  return "20260312_143522123_iPhone15Pro_IMG_4567.jpg"
        case .dateCamera:          return "20260312_143522123_iPhone15Pro.jpg"
        case .dateSeq:             return "20260312_143522123_001.jpg"
        case .dateOnly:            return "20260312_143522.jpg"
        case .yearMonthDayOriginal: return "2026-03-12_IMG_4567.jpg"
        }
    }

    /// Generate the new filename for a file.
    func rename(
        originalName: String,
        date: Date,
        camera: String?,
        sequenceNumber: Int
    ) -> String {
        let ext = (originalName as NSString).pathExtension.lowercased()
        // L-08 FIX: Handle files with only extension (e.g., ".jpg") — use "file" as default stem
        let rawStem = (originalName as NSString).deletingPathExtension
        let stem = rawStem.isEmpty ? "file" : rawStem
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let y = cal.component(.year, from: date)
        let mo = cal.component(.month, from: date)
        let d = cal.component(.day, from: date)
        let h = cal.component(.hour, from: date)
        let mi = cal.component(.minute, from: date)
        let s = cal.component(.second, from: date)
        let ns = cal.component(.nanosecond, from: date)
        let ms = ns / 1_000_000

        let dateMs = String(format: "%04d%02d%02d_%02d%02d%02d%03d", y, mo, d, h, mi, s, ms)
        let dateNoMs = String(format: "%04d%02d%02d_%02d%02d%02d", y, mo, d, h, mi, s)
        let dateDash = String(format: "%04d-%02d-%02d", y, mo, d)
        let safeCam = sanitize(camera ?? "Unknown")
        let seq = String(format: "%03d", sequenceNumber)

        let newStem: String
        switch self {
        case .dateOriginal:
            newStem = dateMs
        case .dateOriginalName:
            newStem = "\(dateMs)_\(stem)"
        case .dateCameraOriginal:
            newStem = "\(dateMs)_\(safeCam)_\(stem)"
        case .dateCamera:
            newStem = "\(dateMs)_\(safeCam)"
        case .dateSeq:
            newStem = "\(dateMs)_\(seq)"
        case .dateOnly:
            newStem = dateNoMs
        case .yearMonthDayOriginal:
            newStem = "\(dateDash)_\(stem)"
        }

        return ext.isEmpty ? newStem : "\(newStem).\(ext)"
    }

    // L-07 FIX: Consistent sanitization — replace with underscore (matches OrganizationPattern)
    private func sanitize(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\0 ")
        var sanitized = name.components(separatedBy: illegal).joined(separator: "_").trimmingCharacters(in: .whitespaces)
        while sanitized.hasPrefix(".") { sanitized = String(sanitized.dropFirst()) }
        if sanitized.isEmpty { sanitized = "Unknown" }
        return sanitized
    }
}
