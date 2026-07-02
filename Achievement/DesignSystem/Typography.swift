import SwiftUI

/// Type roles. Numerals use SF Rounded — friendlier for stats, the same move
/// Apple Fitness makes — while running text stays default SF.
extension Font {
    /// Hero numbers (dashboard ring percentage).
    static let heroNumber = Font.system(size: 44, weight: .bold, design: .rounded)

    /// Large stat values in tiles.
    static let statNumber = Font.system(size: 26, weight: .semibold, design: .rounded)

    /// Small numeric annotations (card progress, counts).
    static let miniNumber = Font.system(size: 13, weight: .semibold, design: .rounded)

    /// Uppercase section/stat labels.
    static let statLabel = Font.system(size: 11, weight: .semibold)
}

extension Text {
    /// The quiet uppercase caption above stat values.
    func statLabelStyle() -> some View {
        self
            .font(.statLabel)
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(.secondary)
    }
}
