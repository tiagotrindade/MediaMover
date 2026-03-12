import Foundation

struct SupportedFormats {
    static let photoExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "tiff", "tif",
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

    static let videoExtensions: Set<String> = [
        "mov", "mp4", "avi", "mkv", "m4v", "3gp", "wmv",
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

    static var allExtensions: Set<String> {
        photoExtensions.union(videoExtensions)
    }

    static func mediaType(for ext: String) -> MediaType? {
        let lower = ext.lowercased()
        if photoExtensions.contains(lower) { return .photo }
        if videoExtensions.contains(lower) { return .video }
        return nil
    }
}
