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
            // M-33 FIX: Don't cache generic system icons by URL (wastes memory)
            // Just return the icon without caching since it's the same for each file type
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 60, height: 60)
            return icon
        }
    }

    func clearCache() {
        cache.removeAllObjects()
    }
}
