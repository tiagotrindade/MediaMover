import Foundation
import AppKit

/// Manages Pro license state via Lemon Squeezy license key validation.
///
/// Flow:
/// 1. User buys Pro via checkout URL → receives license key by email
/// 2. User pastes key in app → `activate()` calls Lemon Squeezy API
/// 3. License key + instance ID stored in macOS Keychain
/// 4. On each launch, `validateOnLaunch()` re-validates (with grace period for offline use)
@Observable
@MainActor
final class ProManager {

    static let shared = ProManager()

    // MARK: - Keychain keys

    private enum Keys {
        static let licenseKey  = "FolioSort_LicenseKey"
        static let instanceId  = "FolioSort_InstanceId"
        static let lastValidated = "FolioSort_LastValidated"
    }

    // MARK: - Published state

    private(set) var isPro: Bool = false
    private(set) var licenseStatus: LicenseStatus = .none
    private(set) var maskedKey: String = ""

    var isActivating = false
    var activationError: String?

    // MARK: - License status

    enum LicenseStatus: Equatable {
        case none               // No license entered
        case active             // Validated successfully
        case expired            // License expired
        case disabled           // License disabled by admin
        case offline            // Can't reach API but within grace period
        case invalid            // Validation failed
    }

    // MARK: - Constants

    /// Grace period for offline validation — 7 days.
    private static let offlineGraceDays: TimeInterval = 7 * 24 * 3600

    /// Re-validate interval — every 24 hours.
    private static let revalidateInterval: TimeInterval = 24 * 3600

    // MARK: - Init

    private init() {
        // Check if a license key exists in Keychain
        if let key = KeychainHelper.load(key: Keys.licenseKey),
           let _ = KeychainHelper.load(key: Keys.instanceId) {
            maskedKey = Self.mask(key)
            // Assume valid until background re-validation
            isPro = true
            licenseStatus = .active
            UserDefaults.standard.set(true, forKey: "FolioSort_ProUnlocked")
        } else {
            // No license in Keychain — ensure stale UserDefaults is cleared
            // (covers upgrades from old ProManager that stored Pro flag in UserDefaults)
            isPro = false
            licenseStatus = .none
            UserDefaults.standard.set(false, forKey: "FolioSort_ProUnlocked")
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - Activate

    /// Activates a new license key. Called from UpgradeView.
    func activate(licenseKey: String) async {
        let trimmed = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            activationError = "Please enter a license key."
            return
        }

        isActivating = true
        activationError = nil

        do {
            let (response, instanceId) = try await LemonSqueezyService.shared.activate(licenseKey: trimmed)

            // Store in Keychain
            KeychainHelper.save(key: Keys.licenseKey, value: trimmed)
            KeychainHelper.save(key: Keys.instanceId, value: instanceId)
            saveLastValidated()

            maskedKey = Self.mask(trimmed)
            isPro = true
            licenseStatus = .active
            isActivating = false

            // Also store backup flag for fast launch
            UserDefaults.standard.set(true, forKey: "FolioSort_ProUnlocked")

            _ = response // suppress unused warning
        } catch let error as LemonSqueezyService.LicenseError {
            isActivating = false
            activationError = error.errorDescription
        } catch {
            isActivating = false
            activationError = error.localizedDescription
        }
    }

    // MARK: - Validate on launch

    /// Call once during app startup to re-validate the stored license.
    func validateOnLaunch() async {
        guard let key = KeychainHelper.load(key: Keys.licenseKey),
              let instanceId = KeychainHelper.load(key: Keys.instanceId) else {
            isPro = false
            licenseStatus = .none
            UserDefaults.standard.set(false, forKey: "FolioSort_ProUnlocked")
            return
        }

        maskedKey = Self.mask(key)

        // Skip if validated recently
        if let last = lastValidatedDate(),
           Date().timeIntervalSince(last) < Self.revalidateInterval {
            isPro = true
            licenseStatus = .active
            return
        }

        // Try to validate online
        do {
            let response = try await LemonSqueezyService.shared.validate(licenseKey: key, instanceId: instanceId)

            if response.valid {
                isPro = true
                licenseStatus = .active
                saveLastValidated()
                UserDefaults.standard.set(true, forKey: "FolioSort_ProUnlocked")
            } else {
                // Check specific status
                let status = response.licenseKey?.status ?? "invalid"
                switch status {
                case "expired":
                    licenseStatus = .expired
                    isPro = false
                case "disabled":
                    licenseStatus = .disabled
                    isPro = false
                default:
                    licenseStatus = .invalid
                    isPro = false
                }
                UserDefaults.standard.set(isPro, forKey: "FolioSort_ProUnlocked")
            }
        } catch {
            // Network error — allow offline grace period
            if let last = lastValidatedDate(),
               Date().timeIntervalSince(last) < Self.offlineGraceDays {
                isPro = true
                licenseStatus = .offline
            } else {
                isPro = false
                licenseStatus = .invalid
            }
        }
    }

    // MARK: - Deactivate

    /// Deactivates the license from this machine and clears stored data.
    func deactivate() async {
        guard let key = KeychainHelper.load(key: Keys.licenseKey),
              let instanceId = KeychainHelper.load(key: Keys.instanceId) else {
            clearAll()
            return
        }

        do {
            try await LemonSqueezyService.shared.deactivate(licenseKey: key, instanceId: instanceId)
        } catch {
            // Deactivation on server failed — clear locally anyway
            // (the user might want to transfer the license to another machine)
        }

        clearAll()
    }

    // MARK: - Debug helpers (only available in DEBUG builds)

    #if DEBUG
    func unlock() {
        isPro = true
        licenseStatus = .active
        UserDefaults.standard.set(true, forKey: "FolioSort_ProUnlocked")
    }

    func lock() {
        isPro = false
        licenseStatus = .none
        UserDefaults.standard.set(false, forKey: "FolioSort_ProUnlocked")
    }
    #endif

    // MARK: - Private

    private func clearAll() {
        KeychainHelper.delete(key: Keys.licenseKey)
        KeychainHelper.delete(key: Keys.instanceId)
        UserDefaults.standard.removeObject(forKey: Keys.lastValidated)
        UserDefaults.standard.set(false, forKey: "FolioSort_ProUnlocked")
        isPro = false
        licenseStatus = .none
        maskedKey = ""
        activationError = nil
    }

    private func saveLastValidated() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Keys.lastValidated)
    }

    private func lastValidatedDate() -> Date? {
        let ts = UserDefaults.standard.double(forKey: Keys.lastValidated)
        guard ts > 0 else { return nil }
        return Date(timeIntervalSince1970: ts)
    }

    private static func mask(_ key: String) -> String {
        guard key.count > 8 else { return "••••••••" }
        let prefix = String(key.prefix(4))
        let suffix = String(key.suffix(4))
        return "\(prefix)••••••••\(suffix)"
    }
}
