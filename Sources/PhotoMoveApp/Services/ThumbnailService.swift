import AppKit
import ImageIO
import AVFoundation

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()
    private var inflight: Set<URL> = []

    private init() {
        cache.countLimit = 2000
    }

    func thumbnail(for url: URL, mediaType: MediaType) -> NSImage? {
        cache.object(forKey: url as NSURL)
    }

    func loadThumbnail(for url: URL, mediaType: MediaType, completion: (@MainActor @Sendable (NSImage?) -> Void)? = nil) {
        if let cached = cache.object(forKey: url as NSURL) {
            completion?(cached)
            return
        }
        guard !inflight.contains(url) else { return }
        inflight.insert(url)

        let fileURL = url
        let type = mediaType
        Task.detached(priority: .utility) {
            let image: NSImage?
            switch type {
            case .photo:
                image = generateImageThumbnail(url: fileURL)
            case .video:
                image = await generateVideoThumbnail(url: fileURL)
            case .other:
                image = await generateSystemIcon(for: fileURL)
            }

            await MainActor.run { [weak self] in
                if let image {
                    self?.cache.setObject(image, forKey: fileURL as NSURL)
                }
                self?.inflight.remove(fileURL)
                completion?(image)
            }
        }
    }

    func clearCache() {
        cache.removeAllObjects()
        inflight.removeAll()
    }
}

// MARK: - Thumbnail generators (free functions, no actor isolation)

private func generateImageThumbnail(url: URL) -> NSImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceThumbnailMaxPixelSize: 80,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}

private func generateVideoThumbnail(url: URL) async -> NSImage? {
    let asset = AVURLAsset(url: url)
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: 80, height: 80)

    do {
        let (cgImage, _) = try await generator.image(at: .zero)
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    } catch {
        return nil
    }
}

@MainActor
private func generateSystemIcon(for url: URL) -> NSImage? {
    let icon = NSWorkspace.shared.icon(forFile: url.path)
    icon.size = NSSize(width: 40, height: 40)
    return icon
}
