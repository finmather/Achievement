import SwiftUI

/// Editorial type scale. Numerals are oversized SF Rounded with tightened
/// tracking — stats should read like a magazine spread, not a spreadsheet.
extension Font {
    /// The dashboard's giant hero percentage.
    static let heroNumber = Font.system(size: 64, weight: .bold, design: .rounded)

    /// Screen titles ("Library", the profile name).
    static let editorialTitle = Font.system(size: 34, weight: .bold, design: .rounded)

    /// Floating section titles.
    static let sectionTitle = Font.system(size: 21, weight: .semibold, design: .rounded)

    /// Prominent stat values.
    static let statNumber = Font.system(size: 28, weight: .semibold, design: .rounded)

    /// Small numeric annotations (counts on chips and rows).
    static let miniNumber = Font.system(size: 13, weight: .semibold, design: .rounded)
}

extension Text {
    /// Kerned uppercase whisper above numbers and sections.
    func capsLabel() -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .kerning(1.6)
            .foregroundStyle(.secondary)
    }

    /// Hero numerals get tighter tracking as they grow.
    func heroNumberStyle() -> some View {
        self
            .font(.heroNumber)
            .tracking(-1.5)
            .contentTransition(.numericText())
    }
}
