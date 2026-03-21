import Foundation

enum FeatureGate: CaseIterable, Sendable {
    case unlimitedFiles
    case allFolderPresets        // >3 presets
    case customTemplates         // Template Builder
    case profiles                // Custom profiles
    case allRenamePresets        // >3 rename presets
    case regexRename
    case rawPhotoFormats
    case rawVideoFormats
    case otherFiles
    case sha256
    case advancedDuplicates      // Ask Each Time + Automatic
    case persistentUndo          // Undo across sessions
    case reverseGeocoding
    case extendedExifTokens      // Lens, ISO, Aperture, ShutterSpeed tokens
    case locationTokens          // City, Country, State, Locality tokens
    case activityLogSearch
    case activityLogExport
    case videoSubfolder
    case renameWithDate

    var requiresPro: Bool { true }

    @MainActor
    static func isAvailable(_ gate: FeatureGate) -> Bool {
        ProManager.shared.isPro
    }

    /// Free tier: first 3 folder presets only
    static let freeFolderPresetCount = 3

    /// Free tier: first 3 rename presets only
    static let freeRenamePresetCount = 3

    /// Free tier: max files per operation
    static let freeFileLimit = 100
}
