import SwiftUI
import UIKit
import AchievementCore

/// Extracts a game's signature colors from its cover art so each detail
/// page feels lit by its own world — Hades in embers, Hollow Knight in
/// cold blues. Extraction is coarse by design (dominant saturated hue),
/// and the result only ever tints ambience and accents, never body text.
enum ArtPalette {
    struct Colors: Equatable {
        /// Mid-brightness accent for glows, chips, and the panel ring.
        let glow: Color
        /// Deep shade for the backdrop scrim.
        let deep: Color
    }

    @MainActor private static var cache: [Int: Colors] = [:]

    @MainActor
    static func colors(appID: Int, image: UIImage?, tags: [String]) -> Colors {
        if let hit = cache[appID] { return hit }
        let computed = image.flatMap(dominantHue).map(colors(fromHue:))
            ?? genreFallback(tags: tags)
        cache[appID] = computed
        return computed
    }

    // MARK: - Pixel work

    /// Dominant saturated hue via a 20×20 downsample and 12-bin hue
    /// histogram weighted by saturation × brightness. Near-grays and
    /// near-blacks don't vote.
    private static func dominantHue(_ image: UIImage) -> Double? {
        guard let cgImage = image.cgImage else { return nil }
        let side = 20
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(
            data: &pixels,
            width: side, height: side,
            bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var bins = [Double](repeating: 0, count: 12)
        var binHueSums = [Double](repeating: 0, count: 12)

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let r = Double(pixels[index]) / 255
            let g = Double(pixels[index + 1]) / 255
            let b = Double(pixels[index + 2]) / 255
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let delta = maxC - minC
            let saturation = maxC == 0 ? 0 : delta / maxC
            guard saturation > 0.25, maxC > 0.18 else { continue }

            var hue: Double
            if delta == 0 {
                continue
            } else if maxC == r {
                hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxC == g {
                hue = (b - r) / delta + 2
            } else {
                hue = (r - g) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }

            let weight = saturation * maxC
            let bin = min(11, Int(hue * 12))
            bins[bin] += weight
            binHueSums[bin] += hue * weight
        }

        guard let best = bins.indices.max(by: { bins[$0] < bins[$1] }),
              bins[best] > 0.5 else { return nil }
        return binHueSums[best] / bins[best]
    }

    private static func colors(fromHue hue: Double) -> Colors {
        Colors(
            glow: Color(hue: hue, saturation: 0.58, brightness: 0.74),
            deep: Color(hue: hue, saturation: 0.52, brightness: 0.24)
        )
    }

    // MARK: - Fallback

    /// When art won't yield a hue (monochrome covers, load failure), the
    /// game's genre picks a plausible one.
    private static func genreFallback(tags: [String]) -> Colors {
        let axis = tags.flatMap(GenreEngine.axes(forTag:)).first
        let hue: Double = switch axis {
        case .roguelike: 0.05   // ember
        case .rpg: 0.11         // gold
        case .platformer: 0.36  // green
        case .puzzle: 0.50      // teal
        case .strategy: 0.60    // blue
        case .fps: 0.99         // red
        case nil: 0.68          // fall back to the app violet
        }
        return colors(fromHue: hue)
    }
}
