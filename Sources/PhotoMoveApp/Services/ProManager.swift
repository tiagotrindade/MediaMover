import Foundation

@Observable
@MainActor
final class ProManager {

    static let shared = ProManager()

    private static let defaultsKey = "FolioSort_ProUnlocked"

    var isPro: Bool {
        didSet {
            UserDefaults.standard.set(isPro, forKey: Self.defaultsKey)
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
