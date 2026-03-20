import AppKit
import ImageIO
import AVFoundation

@MainActor
final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSURL, NSImage>()

    private init() {
        cache.countLimit = 2000
    }

    func thumbnail(for url: URL, mediaType: MediaType) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let fileURL = url
        let type = mediaType
        let image: NSImage? = await Task.detached(priority: .utility) {
            switch type {
            case .photo:  return generateImageThumbnail(url: fileURL)
            case .video:  return await generateVideoThumbnail(url: fileURL)
            case .other:  return await generateSystemIcon(for: fileURL)
            }
        }.value

        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
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
