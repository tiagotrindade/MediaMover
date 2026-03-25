import Foundation

@Observable
@MainActor
final class ProManager {

    static let shared = ProManager()

    private static let defaultsKey = "FolioSort_ProUnlocked"

    // H-16 FIX: Synchronize and verify UserDefaults write
    var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: Self.defaultsKey)
            UserDefaults.standard.synchronize()
        }
    }

    private init() {
        self.isPro = UserDefaults.standard.bool(forKey: Self.defaultsKey)
    }

    func unlock() {
        isPro = true
    }

    func lock() {
        isPro = false
    }
}
