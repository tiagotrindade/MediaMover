import Foundation
import ImageIO
import AVFoundation

struct MetadataExtractor: Sendable {

    // MARK: - Photo EXIF

    static func extractPhotoMetadata(from url: URL) -> (dateTaken: Date?, cameraModel: String?) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return (nil, nil)
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return (nil, nil)
        }

        var dateTaken: Date?
        var cameraModel: String?

        // EXIF date
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let dateString = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            dateTaken = parseExifDate(dateString)
        }

        // TIFF camera model
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let model = tiff[kCGImagePropertyTIFFModel] as? String {
            cameraModel = model.trimmingCharacters(in: .whitespaces)
        }

        return (dateTaken, cameraModel)
    }

    // MARK: - Video metadata

    static func extractVideoMetadata(from url: URL) async -> (dateTaken: Date?, cameraModel: String?) {
        let asset = AVURLAsset(url: url)

        var dateTaken: Date?
        var cameraModel: String?

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
                if let key = item.commonKey, key == .commonKeyModel {
                    if let value = try await item.load(.stringValue) {
                        cameraModel = value.trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        } catch {
            // metadata not available
        }

        return (dateTaken, cameraModel)
    }

    // MARK: - Helpers

    private static func parseExifDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.date(from: string)
    }
}
