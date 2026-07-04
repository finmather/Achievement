import SwiftUI
import UIKit

/// The app's one remote-image loader. Memory cache for instant re-display,
/// URLCache (configured in AchievementApp) for disk persistence, a styled
/// fallback that breathes while loading and sits calmly on failure — a
/// blank rectangle is impossible by construction. Retries automatically
/// when the view reappears after a failure.
struct CachedImage<Fallback: View>: View {
    let url: URL?
    var contentMode: ContentMode = .fill
    var onFailure: (() -> Void)? = nil
    @ViewBuilder var fallback: (_ isLoading: Bool) -> Fallback

    @State private var image: UIImage?
    @State private var isLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                fallback(isLoading)
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard image == nil, let url else { return }
        if let hit = ImagePipeline.cached(url) {
            image = hit // instant, no fade — it was already on screen once
            return
        }
        isLoading = true
        defer { isLoading = false }
        if let loaded = await ImagePipeline.load(url) {
            withAnimation(.easeOut(duration: 0.3)) {
                image = loaded
            }
        } else {
            onFailure?()
        }
    }
}

/// Shared fetch + cache. Also used directly by ArtPalette to get pixels.
enum ImagePipeline {
    private static let memory: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 500
        return cache
    }()

    static func cached(_ url: URL) -> UIImage? {
        memory.object(forKey: url as NSURL)
    }

    static func load(_ url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? true,
              let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: url as NSURL)
        return image
    }
}
