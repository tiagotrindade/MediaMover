import Foundation
import CoreLocation

/// Reverse geocoding service with in-memory + disk caching.
/// Coordinates are rounded to ~3 decimal places (~110m precision) for cache deduplication.
actor GeocodingService {

    static let shared = GeocodingService()

    // MARK: - Cache

    private var memoryCache: [String: LocationInfo] = [:]
    private let cacheURL: URL
    private let geocoder = CLGeocoder()
    private var pendingRequests: [String: [CheckedContinuation<LocationInfo?, Never>]] = [:]

    // Rate limiting: CLGeocoder allows ~50 requests/minute
    private var lastRequestTime: Date = .distantPast
    private let minRequestInterval: TimeInterval = 1.2  // ~50/min with margin

    struct LocationInfo: Codable, Sendable {
        let city: String?
        let country: String?
        let state: String?
        let locality: String?
    }

    // C-05, M-38 FIX: Safe unwrap and handle cache file errors
    private init() {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            cacheURL = FileManager.default.temporaryDirectory.appendingPathComponent("FolioSort/geocoding_cache.json")
            return
        }
        let appDir = support.appendingPathComponent("FolioSort")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        cacheURL = appDir.appendingPathComponent("geocoding_cache.json")

        // Load disk cache
        if let data = try? Data(contentsOf: cacheURL),
           let decoded = try? JSONDecoder().decode([String: LocationInfo].self, from: data) {
            memoryCache = decoded
        }
    }

    // MARK: - Public API

    /// Reverse geocode a coordinate. Returns cached result if available.
    func reverseGeocode(latitude: Double, longitude: Double) async -> LocationInfo? {
        let key = cacheKey(latitude: latitude, longitude: longitude)

        // Check cache first
        if let cached = memoryCache[key] {
            return cached
        }

        // C-03 FIX: Initialize pending array BEFORE checking, so concurrent callers
        // can always append their continuation
        if pendingRequests[key] != nil {
            return await withCheckedContinuation { continuation in
                pendingRequests[key]?.append(continuation)
            }
        }

        // Initialize the pending array first so concurrent calls see it exists
        pendingRequests[key] = []
        // H-15 FIX: Capture rate-limited time atomically
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRequestTime)
        lastRequestTime = now

        // Rate limiting (time already captured above)
        if elapsed < minRequestInterval {
            try? await Task.sleep(nanoseconds: UInt64((minRequestInterval - elapsed) * 1_000_000_000))
        }

        // Perform geocoding
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let result: LocationInfo?

        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                result = LocationInfo(
                    city: placemark.locality,
                    country: placemark.country,
                    state: placemark.administrativeArea,
                    locality: placemark.subLocality
                )
            } else {
                result = nil
            }
        } catch {
            result = nil
        }

        // Only cache successful results — failed lookups (network errors, rate limits)
        // should be retried on next scan
        if let result {
            memoryCache[key] = result
            saveCacheToDisk()
        }

        // Resume pending continuations
        let pending = pendingRequests.removeValue(forKey: key) ?? []
        for continuation in pending {
            continuation.resume(returning: result)
        }

        return result
    }

    /// Batch resolve locations for multiple files. Modifies files in-place.
    /// Reports progress via optional callback.
    func resolveLocations(
        for files: inout [MediaFile],
        progressCallback: (@Sendable (Int, Int) async -> Void)? = nil
    ) async {
        let gpsIndices = files.indices.filter { files[$0].hasGPS }
        let total = gpsIndices.count
        var resolved = 0

        for i in gpsIndices {
            if Task.isCancelled { return }
            guard let lat = files[i].gpsLatitude,
                  let lon = files[i].gpsLongitude else { continue }

            if let info = await reverseGeocode(latitude: lat, longitude: lon) {
                files[i].locationCity = info.city
                files[i].locationCountry = info.country
                files[i].locationState = info.state
                files[i].locationLocality = info.locality
            }
            resolved += 1
            await progressCallback?(resolved, total)
        }
    }

    /// Number of cached locations.
    var cacheCount: Int {
        memoryCache.count
    }

    /// Clear the geocoding cache (memory + disk).
    func clearCache() {
        memoryCache.removeAll()
        try? FileManager.default.removeItem(at: cacheURL)
    }

    // MARK: - Private

    private func cacheKey(latitude: Double, longitude: Double) -> String {
        // Round to 3 decimal places (~110m precision)
        let lat = (latitude * 1000).rounded() / 1000
        let lon = (longitude * 1000).rounded() / 1000
        return "\(lat),\(lon)"
    }

    private func saveCacheToDisk() {
        guard let data = try? JSONEncoder().encode(memoryCache) else { return }
        try? data.write(to: cacheURL)
    }
}
