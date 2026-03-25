import Foundation

/// Handles all communication with the Lemon Squeezy License API.
/// Docs: https://docs.lemonsqueezy.com/api/license-keys
actor LemonSqueezyService {

    static let shared = LemonSqueezyService()

    /// Public checkout URL — opened in the user's default browser.
    static let checkoutURL = URL(string: "https://foliosort.lemonsqueezy.com/checkout/buy/ea44ddb0-9fa7-4555-a0cb-17e7bab0e8d5?media=0&logo=0&desc=0&discount=0")!

    private let baseURL = "https://api.lemonsqueezy.com/v1/licenses"

    // MARK: - Response types

    struct LicenseResponse: Decodable {
        let valid: Bool
        let error: String?
        let licenseKey: LicenseKeyInfo?
        let instance: InstanceInfo?
        let meta: MetaInfo?

        enum CodingKeys: String, CodingKey {
            case valid, error
            case licenseKey = "license_key"
            case instance, meta
        }
    }

    struct LicenseKeyInfo: Decodable {
        let id: Int
        let status: String              // active, inactive, expired, disabled
        let key: String
        let activationLimit: Int
        let activationUsage: Int
        let expiresAt: String?

        enum CodingKeys: String, CodingKey {
            case id, status, key
            case activationLimit = "activation_limit"
            case activationUsage = "activation_usage"
            case expiresAt = "expires_at"
        }
    }

    struct InstanceInfo: Decodable {
        let id: String
        let name: String
    }

    struct MetaInfo: Decodable {
        let storeId: Int?
        let productId: Int?
        let productName: String?
        let variantId: Int?
        let variantName: String?

        enum CodingKeys: String, CodingKey {
            case storeId = "store_id"
            case productId = "product_id"
            case productName = "product_name"
            case variantId = "variant_id"
            case variantName = "variant_name"
        }
    }

    // MARK: - Activate

    /// Activates a license key on this machine.  Returns the instance ID on success.
    func activate(licenseKey: String) async throws -> (response: LicenseResponse, instanceId: String) {
        let body: [String: String] = [
            "license_key":   licenseKey,
            "instance_name": instanceName(),
        ]
        let result: LicenseResponse = try await post(endpoint: "activate", body: body)

        guard result.valid, let instanceId = result.instance?.id else {
            throw LicenseError.activationFailed(result.error ?? result.licenseKey?.status ?? "Unknown error")
        }
        return (result, instanceId)
    }

    // MARK: - Validate

    /// Validates an already-activated license.
    func validate(licenseKey: String, instanceId: String) async throws -> LicenseResponse {
        let body: [String: String] = [
            "license_key": licenseKey,
            "instance_id": instanceId,
        ]
        return try await post(endpoint: "validate", body: body)
    }

    // MARK: - Deactivate

    /// Deactivates the license from this machine.
    func deactivate(licenseKey: String, instanceId: String) async throws {
        let body: [String: String] = [
            "license_key": licenseKey,
            "instance_id": instanceId,
        ]
        let result: LicenseResponse = try await post(endpoint: "deactivate", body: body)
        if !result.valid && result.error != nil {
            throw LicenseError.deactivationFailed(result.error!)
        }
    }

    // MARK: - Helpers

    private func instanceName() -> String {
        let host = Host.current().localizedName ?? "Mac"
        return "FolioSort-\(host)"
    }

    private func post<T: Decodable>(endpoint: String, body: [String: String]) async throws -> T {
        guard let url = URL(string: "\(baseURL)/\(endpoint)") else {
            throw LicenseError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await URLSession.shared.data(for: request)

        guard let http = httpResponse as? HTTPURLResponse else {
            throw LicenseError.networkError("Invalid response")
        }

        guard (200...499).contains(http.statusCode) else {
            throw LicenseError.networkError("HTTP \(http.statusCode)")
        }

        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Errors

    enum LicenseError: LocalizedError {
        case invalidURL
        case networkError(String)
        case activationFailed(String)
        case deactivationFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:                return "Invalid API URL."
            case .networkError(let msg):     return "Network error: \(msg)"
            case .activationFailed(let msg): return "Activation failed: \(msg)"
            case .deactivationFailed(let msg): return "Deactivation failed: \(msg)"
            }
        }
    }
}
