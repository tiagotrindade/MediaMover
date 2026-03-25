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

// C-04 FIX: Use @unchecked Sendable since mutable location fields are only
// written during the single-threaded scan phase before crossing actor boundaries.
struct MediaFile: Identifiable, @unchecked Sendable {
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

    // Extended EXIF metadata (Phase 2)
    let lensModel: String?
    let iso: String?
    let aperture: String?
    let shutterSpeed: String?
    let gpsLatitude: Double?
    let gpsLongitude: Double?

    // Resolved location (filled after reverse geocoding)
    var locationCity: String?
    var locationCountry: String?
    var locationState: String?
    var locationLocality: String?

    /// Whether this file requires Pro to process (RAW formats in Free tier).
    var requiresPro: Bool = false

    /// Volume type where this file resides (local, network, iCloud).
    var volumeType: VolumeType?

    /// iCloud download status (only relevant for iCloud files).
    var iCloudStatus: ICloudDownloadStatus?

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

    /// Whether this file has GPS coordinates.
    var hasGPS: Bool {
        gpsLatitude != nil && gpsLongitude != nil
    }

    /// Build a TemplateContext from this MediaFile for template evaluation.
    func templateContext(fallback: DateFallback = .creationDate, sequenceNumber: Int = 1) -> TemplateContext {
        TemplateContext(
            date: effectiveDate(fallback: fallback),
            cameraModel: cameraModel,
            lensModel: lensModel,
            iso: iso,
            aperture: aperture,
            shutterSpeed: shutterSpeed,
            originalFileName: fileName,
            sequenceNumber: sequenceNumber,
            city: locationCity,
            country: locationCountry,
            state: locationState,
            locality: locationLocality
        )
    }

    init(
        url: URL,
        dateTaken: Date?,
        cameraModel: String?,
        fileCreationDate: Date?,
        fileModificationDate: Date,
        fileSize: Int64,
        mediaType: MediaType? = nil,
        lensModel: String? = nil,
        iso: String? = nil,
        aperture: String? = nil,
        shutterSpeed: String? = nil,
        gpsLatitude: Double? = nil,
        gpsLongitude: Double? = nil
    ) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()
        self.fileSize = fileSize
        self.mediaType = mediaType ?? SupportedFormats.mediaType(for: url.pathExtension) ?? .photo
        self.dateTaken = dateTaken
        self.cameraModel = cameraModel
        self.fileCreationDate = fileCreationDate
        self.fileModificationDate = fileModificationDate
        self.lensModel = lensModel
        self.iso = iso
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.gpsLatitude = gpsLatitude
        self.gpsLongitude = gpsLongitude
    }
}
