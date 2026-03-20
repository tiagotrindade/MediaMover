import AppKit
import QuickLookThumbnailing

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 2000
    }

    func thumbnail(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: 60, height: 60),
            scale: 2.0,
            representationTypes: .all
        )

        do {
            let representation = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = representation.nsImage
            cache.setObject(image, forKey: url as NSURL)
            return image
        } catch {
            // Fallback to system icon
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 60, height: 60)
            cache.setObject(icon, forKey: url as NSURL)
            return icon
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
