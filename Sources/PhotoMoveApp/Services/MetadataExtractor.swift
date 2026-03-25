import Foundation
import ImageIO
import AVFoundation

/// Extended photo metadata result with all EXIF fields needed for template tokens.
struct PhotoMetadata: Sendable {
    let dateTaken: Date?
    let cameraModel: String?
    let lensModel: String?
    let iso: String?
    let aperture: String?
    let shutterSpeed: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
}

/// Extended video metadata result.
struct VideoMetadata: Sendable {
    let dateTaken: Date?
    let cameraModel: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?
}

struct MetadataExtractor: Sendable {

    // MARK: - Photo EXIF (legacy — keeps backward compat)

    static func extractPhotoMetadata(from url: URL) -> (dateTaken: Date?, cameraModel: String?) {
        let extended = extractExtendedPhotoMetadata(from: url)
        return (extended.dateTaken, extended.cameraModel)
    }

    // MARK: - Extended Photo EXIF

    static func extractExtendedPhotoMetadata(from url: URL) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return PhotoMetadata(dateTaken: nil, cameraModel: nil, lensModel: nil, iso: nil, aperture: nil, shutterSpeed: nil, gpsLatitude: nil, gpsLongitude: nil)
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return PhotoMetadata(dateTaken: nil, cameraModel: nil, lensModel: nil, iso: nil, aperture: nil, shutterSpeed: nil, gpsLatitude: nil, gpsLongitude: nil)
        }

        var dateTaken: Date?
        var cameraModel: String?
        var lensModel: String?
        var iso: String?
        var aperture: String?
        var shutterSpeed: String?
        var gpsLatitude: Double?
        var gpsLongitude: Double?

        // EXIF dictionary
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] {
            // Date — fallback chain
            if let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
                dateTaken = parseExifDate(dateString)
            }
            if dateTaken == nil, let dateString = exif[kCGImagePropertyExifDateTimeDigitized] as? String {
                dateTaken = parseExifDate(dateString)
            }

            // Lens model
            if let lens = exif[kCGImagePropertyExifLensModel] as? String {
                lensModel = lens.trimmingCharacters(in: .whitespaces)
            }

            // ISO
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber], let first = isoArray.first {
                iso = first.stringValue
            }

            // Aperture (FNumber)
            if let fNumber = exif[kCGImagePropertyExifFNumber] as? Double {
                aperture = String(format: "f%.1g", fNumber)
            }

            // Shutter speed (ExposureTime)
            if let exposure = exif[kCGImagePropertyExifExposureTime] as? Double {
                if exposure >= 1 {
                    shutterSpeed = String(format: "%.1fs", exposure)
                } else {
                    let denominator = Int(round(1.0 / exposure))
                    // L-10 FIX: Use standard slash notation instead of underscore
                    shutterSpeed = "1-\(denominator)"
                }
            }
        }

        // TIFF dictionary
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            if dateTaken == nil, let dateString = tiff[kCGImagePropertyTIFFDateTime] as? String {
                dateTaken = parseExifDate(dateString)
            }
            if let model = tiff[kCGImagePropertyTIFFModel] as? String {
                cameraModel = model.trimmingCharacters(in: .whitespaces)
            }
        }

        // GPS dictionary
        if let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] {
            // M-24 FIX: Handle non-standard GPS reference strings (e.g., "South", "West")
            if let lat = gps[kCGImagePropertyGPSLatitude] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
                gpsLatitude = latRef.uppercased().hasPrefix("S") ? -lat : lat
            }
            if let lon = gps[kCGImagePropertyGPSLongitude] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
                gpsLongitude = lonRef.uppercased().hasPrefix("W") ? -lon : lon
            }
        }

        return PhotoMetadata(
            dateTaken: dateTaken,
            cameraModel: cameraModel,
            lensModel: lensModel,
            iso: iso,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude
        )
    }

    // MARK: - Video metadata (legacy)

    static func extractVideoMetadata(from url: URL) async -> (dateTaken: Date?, cameraModel: String?) {
        let extended = await extractExtendedVideoMetadata(from: url)
        return (extended.dateTaken, extended.cameraModel)
    }

    // MARK: - Extended Video metadata

    static func extractExtendedVideoMetadata(from url: URL) async -> VideoMetadata {
        let asset = AVURLAsset(url: url)

        var dateTaken: Date?
        var cameraModel: String?
        var gpsLatitude: Double?
        var gpsLongitude: Double?

        do {
            let creationDate = try await asset.load(.creationDate)
            if let dateValue = try await creationDate?.load(.dateValue) {
                dateTaken = dateValue
            }
        } catch {
            // creationDate not available
        }

        do {
            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if let key = item.commonKey {
                    if key == .commonKeyModel {
                        if let value = try await item.load(.stringValue) {
                            cameraModel = value.trimmingCharacters(in: .whitespaces)
                        }
                    } else if key == .commonKeyLocation {
                        if let value = try await item.load(.stringValue) {
                            // ISO 6709 format: "+DD.DDDD-DDD.DDDD+AAA.AAA/"
                            let coords = parseISO6709(value)
                            gpsLatitude = coords.latitude
                            gpsLongitude = coords.longitude
                        }
                    }
                }
            }
        } catch {
            // metadata not available
        }

        return VideoMetadata(
            dateTaken: dateTaken,
            cameraModel: cameraModel,
            gpsLatitude: gpsLatitude,
            gpsLongitude: gpsLongitude
        )
    }

    /// Parse ISO 6709 location string (e.g. "+38.7223-009.1393+024.000/")
    private static func parseISO6709(_ string: String) -> (latitude: Double?, longitude: Double?) {
        let cleaned = string.replacingOccurrences(of: "/", with: "")
        // Pattern: optional sign + digits for lat, then sign + digits for lon
        var lat: Double?
        var lon: Double?

        // Find the second +/- sign (start of longitude)
        var signCount = 0
        var splitIndex = cleaned.startIndex
        for (i, ch) in cleaned.enumerated() {
            if (ch == "+" || ch == "-") && i > 0 {
                signCount += 1
                if signCount == 1 {
                    splitIndex = cleaned.index(cleaned.startIndex, offsetBy: i)
                    break
                }
            }
        }

        if splitIndex > cleaned.startIndex {
            let latStr = String(cleaned[cleaned.startIndex..<splitIndex])
            // Longitude may have altitude appended with another +/-
            let lonPart = String(cleaned[splitIndex...])
            // Find third sign for altitude
            var lonEnd = lonPart.endIndex
            for (i, ch) in lonPart.enumerated() {
                if (ch == "+" || ch == "-") && i > 0 {
                    lonEnd = lonPart.index(lonPart.startIndex, offsetBy: i)
                    break
                }
            }
            let lonStr = String(lonPart[lonPart.startIndex..<lonEnd])

            lat = Double(latStr)
            lon = Double(lonStr)
        }

        return (lat, lon)
    }

    // MARK: - Helpers

    // BUG-META-03 FIX: Static formatters to avoid re-creating on every call
    private static let exifDateFormatterWithSubseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss.SSS"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // BUG-META-02 FIX: Try subseconds first, then standard format
    private static func parseExifDate(_ string: String) -> Date? {
        if let date = exifDateFormatterWithSubseconds.date(from: string) {
            return date
        }
        return exifDateFormatter.date(from: string)
    }
}
