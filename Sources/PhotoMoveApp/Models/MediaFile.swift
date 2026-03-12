import Foundation

enum MediaType: String, CaseIterable, Sendable {
    case photo
    case video
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
    let fileModificationDate: Date

    var effectiveDate: Date {
        dateTaken ?? fileModificationDate
    }

    init(url: URL, dateTaken: Date?, cameraModel: String?, fileModificationDate: Date, fileSize: Int64) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.fileSize = fileSize
        self.mediaType = SupportedFormats.mediaType(for: url.pathExtension) ?? .photo
        self.dateTaken = dateTaken
        self.cameraModel = cameraModel
        self.fileModificationDate = fileModificationDate
    }
}
