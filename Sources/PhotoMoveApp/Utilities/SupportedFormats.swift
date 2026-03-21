import Foundation

struct SupportedFormats {

    // MARK: - Free tier formats

    static let freePhotoExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif"
    ]

    static let freeVideoExtensions: Set<String> = [
        "mov", "mp4", "avi", "mkv", "m4v", "3gp", "wmv"
    ]

    // MARK: - Pro tier formats (RAW + professional)

    static let proPhotoExtensions: Set<String> = [
        // Canon
        "cr2", "cr3", "crw",
        // Nikon
        "nef", "nrw",
        // Sony
        "arw", "sr2", "srf",
        // Adobe / Generic
        "dng",
        // Olympus
        "orf",
        // Fujifilm
        "raf",
        // Panasonic
        "rw2",
        // Pentax
        "pef",
        // Samsung
        "srw",
        // Sigma
        "x3f",
        // Leica
        "rwl",
        // Minolta
        "mrw",
        // Hasselblad
        "3fr", "fff",
        // Phase One
        "iiq",
        // Kodak
        "kdc", "dcr",
        // Epson
        "erf",
        // GoPro / Generic RAW
        "gpr"
    ]

    static let proVideoExtensions: Set<String> = [
        // RAW video
        "braw",  // Blackmagic RAW
        "r3d",   // RED RAW
        "ari",   // ARRI RAW
        "crm",   // Canon Cinema RAW Light
        "mxf",   // Material eXchange Format (broadcast/cinema)
        "mts",   // AVCHD
        "m2ts",  // Blu-ray AVCHD
        "mpg", "mpeg",
        "webm",
        "flv",
        "ts"
    ]

    // MARK: - Full sets (union of free + pro)

    static let photoExtensions: Set<String> = freePhotoExtensions.union(proPhotoExtensions)
    static let videoExtensions: Set<String> = freeVideoExtensions.union(proVideoExtensions)

    static var allExtensions: Set<String> {
        photoExtensions.union(videoExtensions)
    }

    // MARK: - Pro format detection

    static func isProFormat(_ ext: String) -> Bool {
        let lower = ext.lowercased()
        return proPhotoExtensions.contains(lower) || proVideoExtensions.contains(lower)
    }

    static func availablePhotoExtensions(isPro: Bool) -> Set<String> {
        isPro ? photoExtensions : freePhotoExtensions
    }

    static func availableVideoExtensions(isPro: Bool) -> Set<String> {
        isPro ? videoExtensions : freeVideoExtensions
    }

    // MARK: - Media type detection

    static func mediaType(for ext: String) -> MediaType? {
        let lower = ext.lowercased()
        if photoExtensions.contains(lower) { return .photo }
        if videoExtensions.contains(lower) { return .video }
        return nil
    }
}
