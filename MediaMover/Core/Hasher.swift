
import Foundation
import CryptoKit

enum Hasher {
    static func sha256(for url: URL) -> String? {
        do {
            let fileData = try Data(contentsOf: url)
            let hashed = SHA256.hash(data: fileData)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            // Error reading file, cannot compute hash
            print("Error reading file for hashing: \(error)")
            return nil
        }
    }
}
