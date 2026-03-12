import Foundation

enum MediaType: String, CaseIterable, Sendable {
    case photo
    case video
    case other
}

/// Controls what date to use when no EXIF/metadata date is found.
enum DateFallback: String, CaseIterable, Sendable {
    case creationDate = "File Creation Date"
    case modificationDate = "File Modification Date"
    case none = "Skip (no fallback)"
}

struct MediaFile: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let fileName: String
    let fileExtension: String
    let fileSize: Int64
    let mediaType: MediaType
    let dateTaken: Date?
    let cameraModel: String?
    let fileCreationDate: Date?
    let fileModificationDate: Date

    /// Returns the best available date given the user's fallback preference.
    func effectiveDate(fallback: DateFallback = .creationDate) -> Date? {
        if let dateTaken { return dateTaken }
        switch fallback {
        case .creationDate:
            return fileCreationDate ?? fileModificationDate
        case .modificationDate:
            return fileModificationDate
        case .none:
            return nil
        }
    }

    init(url: URL, dateTaken: Date?, cameraModel: String?, fileCreationDate: Date?, fileModificationDate: Date, fileSize: Int64, mediaType: MediaType? = nil) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.fileSize = fileSize
        self.mediaType = mediaType ?? SupportedFormats.mediaType(for: url.pathExtension) ?? .photo
        self.dateTaken = dateTaken
        self.cameraModel = cameraModel
        self.fileCreationDate = fileCreationDate
        self.fileModificationDate = fileModificationDate
    }
}
