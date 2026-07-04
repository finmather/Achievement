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
    /// Kerned uppercase whisper above numbers and sections. Sections may
    /// tint it with their palette's chrome color.
    func capsLabel(_ tint: Color? = nil) -> some View {
        self
            .font(.system(size: 11, weight: .semibold))
            .textCase(.uppercase)
            .kerning(1.6)
            .foregroundStyle(tint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
    }

    /// Hero numerals get tighter tracking as they grow.
    func heroNumberStyle() -> some View {
        self
            .font(.heroNumber)
            .tracking(-1.5)
            .contentTransition(.numericText())
    }
}

/// A number that counts up smoothly when it first appears — stats should
/// arrive, not just sit there.
struct CountUpText: View {
    let value: Int
    var font: Font = .statNumber

    @State private var shown = 0

    var body: some View {
        Text(shown.formatted())
            .font(font)
            .contentTransition(.numericText(value: Double(shown)))
            .onAppear {
                guard shown != value else { return }
                withAnimation(.sweep.delay(0.15)) { shown = value }
            }
            .onChange(of: value) { _, newValue in
                withAnimation(.settle) { shown = newValue }
            }
    }
}
