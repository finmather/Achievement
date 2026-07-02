import SwiftUI

/// The signature progress element. Animates from its previous value with a
/// gentle spring whenever progress changes, and sweeps in on first appearance.
struct CompletionRing<Center: View>: View {
    var fraction: Double
    var isPerfect: Bool = false
    var lineWidth: CGFloat = 10
    var animatesOnAppear: Bool = true
    @ViewBuilder var center: () -> Center

    @State private var displayed: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.0001, displayed))
                .stroke(
                    AngularGradient(
                        colors: gradientColors,
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * max(0.25, displayed))
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .opacity(fraction > 0 ? 1 : 0)

            center()
        }
        .padding(lineWidth / 2)
        .onAppear {
            if animatesOnAppear {
                withAnimation(.spring(duration: 1.1, bounce: 0.18).delay(0.15)) {
                    displayed = fraction
                }
            } else {
                displayed = fraction
            }
        }
        .onChange(of: fraction) { _, newValue in
            withAnimation(.spring(duration: 0.8, bounce: 0.22)) {
                displayed = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion")
        .accessibilityValue("\(Int((fraction * 100).rounded())) percent")
    }

    private var gradientColors: [Color] {
        let colors = Theme.completionColors(fraction: fraction, isPerfect: isPerfect)
        // Close the angular loop so the cap color matches the start.
        return colors + [colors[0]]
    }
}

extension CompletionRing where Center == EmptyView {
    init(
        fraction: Double,
        isPerfect: Bool = false,
        lineWidth: CGFloat = 10,
        animatesOnAppear: Bool = true
    ) {
        self.init(
            fraction: fraction,
            isPerfect: isPerfect,
            lineWidth: lineWidth,
            animatesOnAppear: animatesOnAppear
        ) { EmptyView() }
    }
}

#Preview("Rings", traits: .sizeThatFitsLayout) {
    HStack(spacing: 24) {
        CompletionRing(fraction: 0.2, lineWidth: 6)
            .frame(width: 44, height: 44)
        CompletionRing(fraction: 0.55, lineWidth: 8)
            .frame(width: 64, height: 64)
        CompletionRing(fraction: 1.0, isPerfect: true, lineWidth: 10)
            .frame(width: 88, height: 88)
    }
    .padding()
}
