import Foundation

// MARK: - Organizer Profile

struct OrganizerProfile: Identifiable, Codable, Sendable, Equatable {
    var id: UUID
    var name: String
    var isBuiltIn: Bool

    // Template patterns
    var folderTemplate: String
    var renameTemplate: String?  // nil = no rename

    // Operation settings
    var operationMode: String   // "Copy" or "Move"
    var separateVideos: Bool
    var renameWithDate: Bool

    // File type filters
    var includePhotos: Bool
    var includeVideos: Bool
    var includeOtherFiles: Bool

    // Duplicate handling
    var duplicateStrategy: String  // "Ask Each Time", "Automatic", "Don't Move"
    var duplicateAction: String    // "Rename File", "Replace", "Replace if Larger"

    // Safety
    var verifyIntegrity: Bool
    var hashAlgorithm: String     // "XXHash64" or "SHA-256"

    // Metadata
    var dateFallback: String      // "File Creation Date", "File Modification Date", "Skip (no fallback)"
    var geocodingEnabled: Bool

    // H-17 FIX: Compare all meaningful fields, not just ID
    static func == (lhs: OrganizerProfile, rhs: OrganizerProfile) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.folderTemplate == rhs.folderTemplate &&
        lhs.operationMode == rhs.operationMode &&
        lhs.separateVideos == rhs.separateVideos &&
        lhs.renameWithDate == rhs.renameWithDate &&
        lhs.verifyIntegrity == rhs.verifyIntegrity &&
        lhs.hashAlgorithm == rhs.hashAlgorithm
    }

    // Provide default for geocodingEnabled so old JSON files decode without error
    enum CodingKeys: String, CodingKey {
        case id, name, isBuiltIn, folderTemplate, renameTemplate
        case operationMode, separateVideos, renameWithDate
        case includePhotos, includeVideos, includeOtherFiles
        case duplicateStrategy, duplicateAction
        case verifyIntegrity, hashAlgorithm
        case dateFallback, geocodingEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isBuiltIn = try c.decode(Bool.self, forKey: .isBuiltIn)
        folderTemplate = try c.decode(String.self, forKey: .folderTemplate)
        renameTemplate = try c.decodeIfPresent(String.self, forKey: .renameTemplate)
        operationMode = try c.decode(String.self, forKey: .operationMode)
        separateVideos = try c.decode(Bool.self, forKey: .separateVideos)
        renameWithDate = try c.decode(Bool.self, forKey: .renameWithDate)
        includePhotos = try c.decode(Bool.self, forKey: .includePhotos)
        includeVideos = try c.decode(Bool.self, forKey: .includeVideos)
        includeOtherFiles = try c.decode(Bool.self, forKey: .includeOtherFiles)
        duplicateStrategy = try c.decode(String.self, forKey: .duplicateStrategy)
        duplicateAction = try c.decode(String.self, forKey: .duplicateAction)
        verifyIntegrity = try c.decode(Bool.self, forKey: .verifyIntegrity)
        hashAlgorithm = try c.decode(String.self, forKey: .hashAlgorithm)
        dateFallback = try c.decode(String.self, forKey: .dateFallback)
        geocodingEnabled = try c.decodeIfPresent(Bool.self, forKey: .geocodingEnabled) ?? true
    }

    init(
        id: UUID,
        name: String,
        isBuiltIn: Bool,
        folderTemplate: String,
        renameTemplate: String?,
        operationMode: String,
        separateVideos: Bool,
        renameWithDate: Bool,
        includePhotos: Bool,
        includeVideos: Bool,
        includeOtherFiles: Bool,
        duplicateStrategy: String,
        duplicateAction: String,
        verifyIntegrity: Bool,
        hashAlgorithm: String,
        dateFallback: String,
        geocodingEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.folderTemplate = folderTemplate
        self.renameTemplate = renameTemplate
        self.operationMode = operationMode
        self.separateVideos = separateVideos
        self.renameWithDate = renameWithDate
        self.includePhotos = includePhotos
        self.includeVideos = includeVideos
        self.includeOtherFiles = includeOtherFiles
        self.duplicateStrategy = duplicateStrategy
        self.duplicateAction = duplicateAction
        self.verifyIntegrity = verifyIntegrity
        self.hashAlgorithm = hashAlgorithm
        self.dateFallback = dateFallback
        self.geocodingEnabled = geocodingEnabled
    }
}

// MARK: - Profile Manager

@Observable
@MainActor
final class ProfileManager {

    static let shared = ProfileManager()

    var profiles: [OrganizerProfile] = []
    var selectedProfileId: UUID?

    var selectedProfile: OrganizerProfile? {
        profiles.first(where: { $0.id == selectedProfileId })
    }

    private let presetsURL: URL

    // C-05 FIX: Safe unwrap of Application Support directory
    private init() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("FolioSort/presets")
            try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            presetsURL = fallback
            loadProfiles()
            ensureBuiltInPresets()
            return
        }
        let appDir = support.appendingPathComponent("FolioSort/presets")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        presetsURL = appDir
        loadProfiles()
        ensureBuiltInPresets()
    }

    // MARK: - Built-in Presets

    private static let builtInPresets: [OrganizerProfile] = [
        OrganizerProfile(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000001")!,
            name: "Photography \u{2014} by date",
            isBuiltIn: true,
            folderTemplate: "{YYYY}/{MM}/{DD}",
            renameTemplate: nil,
            operationMode: "Copy",
            separateVideos: true,
            renameWithDate: false,
            includePhotos: true,
            includeVideos: true,
            includeOtherFiles: false,
            duplicateStrategy: "Ask Each Time",
            duplicateAction: "Rename File",
            verifyIntegrity: true,
            hashAlgorithm: "XXHash64",
            dateFallback: "File Creation Date",
            geocodingEnabled: true
        ),
        OrganizerProfile(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000002")!,
            name: "Photography \u{2014} by camera",
            isBuiltIn: true,
            folderTemplate: "{YYYY}/{MM}/{Camera}",
            renameTemplate: nil,
            operationMode: "Copy",
            separateVideos: true,
            renameWithDate: false,
            includePhotos: true,
            includeVideos: true,
            includeOtherFiles: false,
            duplicateStrategy: "Ask Each Time",
            duplicateAction: "Rename File",
            verifyIntegrity: true,
            hashAlgorithm: "XXHash64",
            dateFallback: "File Creation Date",
            geocodingEnabled: true
        ),
        OrganizerProfile(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000003")!,
            name: "Video production",
            isBuiltIn: true,
            folderTemplate: "{YYYY}/{MM}/{DD}/Videos",
            renameTemplate: nil,
            operationMode: "Copy",
            separateVideos: false,
            renameWithDate: true,
            includePhotos: true,
            includeVideos: true,
            includeOtherFiles: false,
            duplicateStrategy: "Automatic",
            duplicateAction: "Rename File",
            verifyIntegrity: true,
            hashAlgorithm: "XXHash64",
            dateFallback: "File Creation Date",
            geocodingEnabled: true
        ),
        OrganizerProfile(
            id: UUID(uuidString: "00000000-0001-0000-0000-000000000004")!,
            name: "Archive \u{2014} flat",
            isBuiltIn: true,
            folderTemplate: "{YYYY}_{MM}_{DD}",
            renameTemplate: nil,
            operationMode: "Copy",
            separateVideos: false,
            renameWithDate: true,
            includePhotos: true,
            includeVideos: true,
            includeOtherFiles: true,
            duplicateStrategy: "Automatic",
            duplicateAction: "Rename File",
            verifyIntegrity: true,
            hashAlgorithm: "SHA-256",
            dateFallback: "File Creation Date",
            geocodingEnabled: true
        ),
    ]

    private func ensureBuiltInPresets() {
        let existingIds = Set(profiles.map(\.id))

        for preset in Self.builtInPresets {
            if !existingIds.contains(preset.id) {
                profiles.insert(preset, at: 0)
            }
        }

        // Sort: built-in first, then user presets alphabetically
        profiles.sort { a, b in
            if a.isBuiltIn != b.isBuiltIn { return a.isBuiltIn }
            if a.isBuiltIn && b.isBuiltIn {
                let aIdx = Self.builtInPresets.firstIndex(where: { $0.id == a.id }) ?? 0
                let bIdx = Self.builtInPresets.firstIndex(where: { $0.id == b.id }) ?? 0
                return aIdx < bIdx
            }
            return a.name < b.name
        }

        saveAllProfiles()
    }

    // MARK: - CRUD

    func addProfile(_ profile: OrganizerProfile) {
        profiles.append(profile)
        saveProfile(profile)
    }

    func updateProfile(_ profile: OrganizerProfile) {
        guard !profile.isBuiltIn else { return }  // Can't edit built-in
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx] = profile
            saveProfile(profile)
        }
    }

    func deleteProfile(_ profile: OrganizerProfile) {
        guard !profile.isBuiltIn else { return }  // Can't delete built-in
        profiles.removeAll(where: { $0.id == profile.id })
        let fileURL = presetsURL.appendingPathComponent("\(profile.id.uuidString).json")
        try? FileManager.default.removeItem(at: fileURL)
        if selectedProfileId == profile.id {
            selectedProfileId = nil
        }
    }

    func duplicateProfile(_ profile: OrganizerProfile) -> OrganizerProfile {
        var copy = profile
        copy.id = UUID()
        copy.name = "\(profile.name) (Copy)"
        copy.isBuiltIn = false
        addProfile(copy)
        return copy
    }

    // MARK: - Apply Profile to ViewModel

    func applyProfile(_ profile: OrganizerProfile, to vm: OrganizerViewModel) {
        vm.folderTemplate = profile.folderTemplate
        vm.operationMode = OperationMode(rawValue: profile.operationMode) ?? .copy
        vm.separateVideos = profile.separateVideos
        vm.renameWithDate = profile.renameWithDate
        vm.includePhotos = profile.includePhotos
        vm.includeVideos = profile.includeVideos
        vm.includeOtherFiles = profile.includeOtherFiles
        vm.duplicateStrategy = DuplicateStrategy(rawValue: profile.duplicateStrategy) ?? .ask
        vm.duplicateAction = DuplicateAction(rawValue: profile.duplicateAction) ?? .rename
        vm.verifyIntegrity = profile.verifyIntegrity
        vm.hashAlgorithm = HashAlgorithm(rawValue: profile.hashAlgorithm) ?? .xxhash64
        vm.dateFallback = DateFallback(rawValue: profile.dateFallback) ?? .creationDate
        vm.geocodingEnabled = profile.geocodingEnabled
        selectedProfileId = profile.id
    }

    /// Create a profile from current ViewModel settings.
    func profileFromViewModel(_ vm: OrganizerViewModel, name: String) -> OrganizerProfile {
        OrganizerProfile(
            id: UUID(),
            name: name,
            isBuiltIn: false,
            folderTemplate: vm.folderTemplate,
            renameTemplate: nil,
            operationMode: vm.operationMode.rawValue,
            separateVideos: vm.separateVideos,
            renameWithDate: vm.renameWithDate,
            includePhotos: vm.includePhotos,
            includeVideos: vm.includeVideos,
            includeOtherFiles: vm.includeOtherFiles,
            duplicateStrategy: vm.duplicateStrategy.rawValue,
            duplicateAction: vm.duplicateAction.rawValue,
            verifyIntegrity: vm.verifyIntegrity,
            hashAlgorithm: vm.hashAlgorithm.rawValue,
            dateFallback: vm.dateFallback.rawValue,
            geocodingEnabled: vm.geocodingEnabled
        )
    }

    // MARK: - Persistence

    private func loadProfiles() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: presetsURL, includingPropertiesForKeys: nil) else { return }

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let profile = try? JSONDecoder().decode(OrganizerProfile.self, from: data) {
                profiles.append(profile)
            }
        }
    }

    private func saveProfile(_ profile: OrganizerProfile) {
        let fileURL = presetsURL.appendingPathComponent("\(profile.id.uuidString).json")
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: fileURL)
    }

    private func saveAllProfiles() {
        for profile in profiles {
            saveProfile(profile)
        }
    }
}
