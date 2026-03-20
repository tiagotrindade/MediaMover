import Foundation

// MARK: - Template Token

/// Represents a single token in a template string.
enum TemplateToken: Equatable, Hashable, Sendable {
    // Date tokens
    case yyyy, yy, mm, dd, hh, minute, ss
    case monthFull   // {Month} → "March"
    case monthShort  // {Mon} → "Mar"

    // Metadata tokens
    case camera, lens, iso, aperture, shutterSpeed

    // File tokens
    case original    // original filename (stem)
    case ext         // extension lowercase
    case extOriginal // {Extension} preserves case
    case counter     // sequential, default 3 digits
    case counterPadded(Int) // {Counter:4} → zero-padded

    // Location tokens
    case city, country, state, locality

    // Literal text (separators, path separators, etc.)
    case literal(String)

    /// Display label for the token chip in the UI.
    var displayLabel: String {
        switch self {
        case .yyyy:         return "{YYYY}"
        case .yy:           return "{YY}"
        case .mm:           return "{MM}"
        case .dd:           return "{DD}"
        case .hh:           return "{HH}"
        case .minute:       return "{mm}"
        case .ss:           return "{ss}"
        case .monthFull:    return "{Month}"
        case .monthShort:   return "{Mon}"
        case .camera:       return "{Camera}"
        case .lens:         return "{Lens}"
        case .iso:          return "{ISO}"
        case .aperture:     return "{Aperture}"
        case .shutterSpeed: return "{ShutterSpeed}"
        case .original:     return "{Original}"
        case .ext:          return "{Ext}"
        case .extOriginal:  return "{Extension}"
        case .counter:      return "{Counter}"
        case .counterPadded(let n): return "{Counter:\(n)}"
        case .city:         return "{City}"
        case .country:      return "{Country}"
        case .state:        return "{State}"
        case .locality:     return "{Locality}"
        case .literal(let s): return s
        }
    }

    /// Category for UI grouping.
    var category: TokenCategory {
        switch self {
        case .yyyy, .yy, .mm, .dd, .hh, .minute, .ss, .monthFull, .monthShort:
            return .date
        case .camera, .lens, .iso, .aperture, .shutterSpeed:
            return .metadata
        case .original, .ext, .extOriginal, .counter, .counterPadded:
            return .file
        case .city, .country, .state, .locality:
            return .location
        case .literal:
            return .separator
        }
    }

    /// Whether this token is a GPS/location token (may be unavailable).
    var isLocationToken: Bool {
        category == .location
    }

    enum TokenCategory: String, CaseIterable, Sendable {
        case date = "Date"
        case metadata = "Metadata"
        case file = "File"
        case location = "Location"
        case separator = "Separator"
    }
}

// MARK: - Template Context

/// All the data needed to evaluate a template for a single file.
struct TemplateContext: Sendable {
    let date: Date?
    let cameraModel: String?
    let lensModel: String?
    let iso: String?
    let aperture: String?
    let shutterSpeed: String?
    let originalFileName: String       // full filename with extension
    let sequenceNumber: Int
    let city: String?
    let country: String?
    let state: String?
    let locality: String?

    var originalStem: String {
        (originalFileName as NSString).deletingPathExtension
    }

    var originalExtension: String {
        (originalFileName as NSString).pathExtension
    }

    var lowercaseExtension: String {
        originalExtension.lowercased()
    }

    init(
        date: Date? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        iso: String? = nil,
        aperture: String? = nil,
        shutterSpeed: String? = nil,
        originalFileName: String = "",
        sequenceNumber: Int = 1,
        city: String? = nil,
        country: String? = nil,
        state: String? = nil,
        locality: String? = nil
    ) {
        self.date = date
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.iso = iso
        self.aperture = aperture
        self.shutterSpeed = shutterSpeed
        self.originalFileName = originalFileName
        self.sequenceNumber = sequenceNumber
        self.city = city
        self.country = country
        self.state = state
        self.locality = locality
    }
}

// MARK: - Template Validation Result

struct TemplateValidation: Sendable {
    let isValid: Bool
    let errors: [String]

    static let valid = TemplateValidation(isValid: true, errors: [])
    static func invalid(_ errors: [String]) -> TemplateValidation {
        TemplateValidation(isValid: false, errors: errors)
    }
}

// MARK: - Template Engine

struct TemplateEngine: Sendable {

    // MARK: - Token registry

    /// All known token names mapped to their TemplateToken values.
    private static let tokenMap: [String: TemplateToken] = [
        "YYYY": .yyyy, "YY": .yy, "MM": .mm, "DD": .dd,
        "HH": .hh, "mm": .minute, "ss": .ss,
        "Month": .monthFull, "Mon": .monthShort,
        "Camera": .camera, "Lens": .lens, "ISO": .iso,
        "Aperture": .aperture, "ShutterSpeed": .shutterSpeed,
        "Original": .original, "Extension": .extOriginal, "Ext": .ext,
        "Counter": .counter,
        "City": .city, "Country": .country, "State": .state, "Locality": .locality,
    ]

    /// Available tokens for the UI palette, grouped by category.
    static let availableTokens: [(category: TemplateToken.TokenCategory, tokens: [TemplateToken])] = [
        (.date, [.yyyy, .yy, .mm, .dd, .hh, .minute, .ss, .monthFull, .monthShort]),
        (.metadata, [.camera, .lens, .iso, .aperture, .shutterSpeed]),
        (.file, [.original, .ext, .extOriginal, .counter, .counterPadded(4)]),
        (.location, [.city, .country, .state, .locality]),
    ]

    // MARK: - Parsing

    /// Parse a template string like "{YYYY}/{MM}/{Camera}/{Original}.{Ext}" into tokens.
    static func parse(_ template: String) -> [TemplateToken] {
        var tokens: [TemplateToken] = []
        var i = template.startIndex
        var literalBuffer = ""

        while i < template.endIndex {
            let ch = template[i]

            if ch == "{" {
                // Flush literal buffer
                if !literalBuffer.isEmpty {
                    tokens.append(.literal(literalBuffer))
                    literalBuffer = ""
                }

                // Find closing brace
                if let closingIndex = template[i...].firstIndex(of: "}") {
                    let tokenContent = String(template[template.index(after: i)..<closingIndex])

                    if let token = resolveToken(tokenContent) {
                        tokens.append(token)
                    } else {
                        // Unknown token — keep as literal with braces
                        tokens.append(.literal("{\(tokenContent)}"))
                    }

                    i = template.index(after: closingIndex)
                    continue
                } else {
                    // No closing brace — treat as literal
                    literalBuffer.append(ch)
                }
            } else {
                literalBuffer.append(ch)
            }

            i = template.index(after: i)
        }

        if !literalBuffer.isEmpty {
            tokens.append(.literal(literalBuffer))
        }

        return tokens
    }

    /// Resolve a token name (inside braces) to a TemplateToken.
    private static func resolveToken(_ content: String) -> TemplateToken? {
        // Check for Counter:N pattern
        if content.hasPrefix("Counter:") {
            let paddingStr = String(content.dropFirst("Counter:".count))
            if let padding = Int(paddingStr), padding > 0, padding <= 10 {
                return .counterPadded(padding)
            }
            return nil
        }

        return tokenMap[content]
    }

    // MARK: - Evaluation

    /// Evaluate a parsed token list with the given context.
    /// Returns the resulting string (may be a path with `/` separators).
    static func evaluate(tokens: [TemplateToken], context: TemplateContext) -> String {
        let cal = Calendar(identifier: .gregorian)
        let unknownFallback = "Unknown"

        return tokens.map { token -> String in
            switch token {
            case .yyyy:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%04d", cal.component(.year, from: date))
            case .yy:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%02d", cal.component(.year, from: date) % 100)
            case .mm:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%02d", cal.component(.month, from: date))
            case .dd:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%02d", cal.component(.day, from: date))
            case .hh:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%02d", cal.component(.hour, from: date))
            case .minute:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%02d", cal.component(.minute, from: date))
            case .ss:
                guard let date = context.date else { return unknownFallback }
                return String(format: "%02d", cal.component(.second, from: date))
            case .monthFull:
                guard let date = context.date else { return unknownFallback }
                return monthName(from: date, abbreviated: false)
            case .monthShort:
                guard let date = context.date else { return unknownFallback }
                return monthName(from: date, abbreviated: true)
            case .camera:
                return sanitize(context.cameraModel ?? unknownFallback)
            case .lens:
                return sanitize(context.lensModel ?? unknownFallback)
            case .iso:
                return context.iso ?? unknownFallback
            case .aperture:
                return context.aperture ?? unknownFallback
            case .shutterSpeed:
                return context.shutterSpeed ?? unknownFallback
            case .original:
                return context.originalStem
            case .ext:
                return context.lowercaseExtension
            case .extOriginal:
                return context.originalExtension
            case .counter:
                return String(format: "%03d", context.sequenceNumber)
            case .counterPadded(let n):
                return String(format: "%0\(n)d", context.sequenceNumber)
            case .city:
                return sanitize(context.city ?? unknownFallback)
            case .country:
                return sanitize(context.country ?? unknownFallback)
            case .state:
                return sanitize(context.state ?? unknownFallback)
            case .locality:
                return sanitize(context.locality ?? unknownFallback)
            case .literal(let s):
                return s
            }
        }.joined()
    }

    /// Convenience: parse + evaluate in one step.
    static func evaluate(template: String, context: TemplateContext) -> String {
        let tokens = parse(template)
        return evaluate(tokens: tokens, context: context)
    }

    // MARK: - Folder path vs filename

    /// Given a full template result, split into folder subpath and filename.
    /// The last `/`-separated component is the filename; everything before is the folder path.
    /// If there's no `/`, the entire string is the filename with no folder path.
    static func splitPath(_ result: String) -> (folderPath: String, fileName: String) {
        let components = result.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if components.count <= 1 {
            return ("", result)
        }
        let folderPath = components.dropLast().joined(separator: "/")
        let fileName = components.last ?? result
        return (folderPath, fileName)
    }

    // MARK: - Validation

    /// Validate a template string.
    static func validate(_ template: String) -> TemplateValidation {
        if template.trimmingCharacters(in: .whitespaces).isEmpty {
            return .invalid(["Template cannot be empty"])
        }

        var errors: [String] = []
        let tokens = parse(template)

        // Check for unknown tokens (they'd be literals containing braces)
        for token in tokens {
            if case .literal(let s) = token {
                // Find any {foo} patterns in literals — these are unrecognized tokens
                let pattern = try? NSRegularExpression(pattern: "\\{([^}]+)\\}")
                let matches = pattern?.matches(in: s, range: NSRange(s.startIndex..., in: s)) ?? []
                for match in matches {
                    if let range = Range(match.range(at: 1), in: s) {
                        errors.append("Unknown token: {\(s[range])}")
                    }
                }
            }
        }

        // Check the template would produce a non-empty result (at least one non-literal token)
        let hasTokens = tokens.contains { if case .literal = $0 { return false } else { return true } }
        if !hasTokens {
            errors.append("Template must contain at least one token (e.g., {YYYY}, {Original})")
        }

        // Check for consecutive path separators
        if template.contains("//") {
            errors.append("Template contains consecutive path separators (//)")
        }

        return errors.isEmpty ? .valid : .invalid(errors)
    }

    // MARK: - Preset Templates

    /// Built-in folder organization presets (replacing the old 7 fixed patterns).
    static let folderPresets: [(name: String, template: String)] = [
        ("YYYY / MM / DD",            "{YYYY}/{MM}/{DD}"),
        ("YYYY / MM",                 "{YYYY}/{MM}"),
        ("YYYY_MM_DD",                "{YYYY}_{MM}_{DD}"),
        ("YYYY / MM / DD / Camera",   "{YYYY}/{MM}/{DD}/{Camera}"),
        ("YYYY / MM / Camera",        "{YYYY}/{MM}/{Camera}"),
        ("Camera / YYYY / MM / DD",   "{Camera}/{YYYY}/{MM}/{DD}"),
        ("YYYY",                      "{YYYY}"),
    ]

    /// Built-in rename presets (replacing the old 7 fixed patterns).
    static let renamePresets: [(name: String, template: String)] = [
        ("Date_Original",          "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}.{Ext}"),
        ("Date_OriginalName",      "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}_{Original}.{Ext}"),
        ("Date_Camera_Original",   "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}_{Camera}_{Original}.{Ext}"),
        ("Date_Camera",            "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}_{Camera}.{Ext}"),
        ("Date_Sequence",          "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}.{Ext}"),
        ("Date Only",              "{YYYY}{MM}{DD}_{HH}{mm}{ss}.{Ext}"),
        ("YYYY-MM-DD_Original",    "{YYYY}-{MM}-{DD}_{Original}.{Ext}"),
    ]

    // MARK: - Helpers

    private static func monthName(from date: Date, abbreviated: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = abbreviated ? "MMM" : "MMMM"
        return formatter.string(from: date)
    }

    /// Sanitize a string for use in folder/file names.
    static func sanitize(_ name: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name.components(separatedBy: illegal)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Convert a legacy OrganizationPattern to a template string.
    static func templateFromLegacyPattern(_ pattern: OrganizationPattern) -> String {
        switch pattern {
        case .yearMonthDay:       return "{YYYY}/{MM}/{DD}"
        case .yearMonth:          return "{YYYY}/{MM}"
        case .yearMonthDayFlat:   return "{YYYY}_{MM}_{DD}"
        case .yearMonthDayCamera: return "{YYYY}/{MM}/{DD}/{Camera}"
        case .yearMonthCamera:    return "{YYYY}/{MM}/{Camera}"
        case .cameraYearMonthDay: return "{Camera}/{YYYY}/{MM}/{DD}"
        case .yearOnly:           return "{YYYY}"
        }
    }

    /// Convert a legacy RenamePattern to a template string.
    static func templateFromLegacyRenamePattern(_ pattern: RenamePattern) -> String {
        switch pattern {
        case .dateOriginal:        return "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}.{Ext}"
        case .dateOriginalName:    return "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}_{Original}.{Ext}"
        case .dateCameraOriginal:  return "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}_{Camera}_{Original}.{Ext}"
        case .dateCamera:          return "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}_{Camera}.{Ext}"
        case .dateSeq:             return "{YYYY}{MM}{DD}_{HH}{mm}{ss}_{Counter:3}.{Ext}"
        case .dateOnly:            return "{YYYY}{MM}{DD}_{HH}{mm}{ss}.{Ext}"
        case .yearMonthDayOriginal: return "{YYYY}-{MM}-{DD}_{Original}.{Ext}"
        }
    }

    /// Generate an example path for a template using sample data.
    static func examplePath(template: String, camera: String = "iPhone 15 Pro") -> String {
        let sampleDate = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            var comps = DateComponents()
            comps.year = 2026; comps.month = 3; comps.day = 12
            comps.hour = 14; comps.minute = 35; comps.second = 22
            return cal.date(from: comps) ?? Date()
        }()

        let context = TemplateContext(
            date: sampleDate,
            cameraModel: camera,
            lensModel: "24-70mm f/2.8",
            iso: "400",
            aperture: "f2.8",
            shutterSpeed: "1_250",
            originalFileName: "IMG_4567.jpg",
            sequenceNumber: 1,
            city: "Lisbon",
            country: "Portugal",
            state: "Lisboa",
            locality: "Bairro Alto"
        )

        return evaluate(template: template, context: context)
    }
}
