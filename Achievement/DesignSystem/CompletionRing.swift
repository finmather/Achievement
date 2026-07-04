import SwiftUI

/// The signature meter, built to the Apple Fitness bar: a track with real
/// depth (rim light + inner shade), an angular-gradient arc with rounded
/// caps, a glowing endpoint dot riding the tip, and two glow layers.
///
/// It can never clip: every effect — glow bleed, dot overhang, stroke
/// width — is absorbed by internal insets, so parents may frame and clip
/// freely. Progress sweeps in with the app's `.sweep` spring and re-springs
/// on change.
struct CompletionRing<Center: View>: View {
    var fraction: Double
    var isPerfect: Bool = false
    var lineWidth: CGFloat = 10
    var animatesOnAppear: Bool = true
    var showsGlow: Bool = true
    /// Art-derived pages may re-hue the arc; the shape language stays.
    var gradientOverride: [Color]? = nil
    @ViewBuilder var center: () -> Center

    @State private var displayed: Double = 0
    @Environment(\.colorScheme) private var scheme

    /// Headroom that keeps glow + dot inside the component's own bounds.
    private var inset: CGFloat {
        lineWidth / 2 + (showsGlow ? lineWidth * 1.5 : lineWidth * 0.35)
    }

    var body: some View {
        ZStack {
            track

            if showsGlow {
                arc.blur(radius: lineWidth * 1.25)
                    .opacity(isPerfect ? 0.62 : 0.42)
                arc.blur(radius: lineWidth * 0.45)
                    .opacity(0.5)
            }
            arc

            endpointDot

            center()
        }
        .padding(inset)
        .onAppear {
            if animatesOnAppear {
                withAnimation(.sweep.delay(0.15)) {
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

    // MARK: - Layers

    private var track: some View {
        ZStack {
            Circle()
                .stroke(
                    scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.07),
                    lineWidth: lineWidth
                )
            // Rim light on the outer edge…
            Circle()
                .stroke(
                    scheme == .dark ? Color.white.opacity(0.06) : Color.white.opacity(0.5),
                    lineWidth: 0.8
                )
                .padding(-(lineWidth / 2 - 0.4))
            // …and a whisper of shade on the inner edge give the groove depth.
            Circle()
                .stroke(
                    Color.black.opacity(scheme == .dark ? 0.28 : 0.06),
                    lineWidth: 0.8
                )
                .padding(lineWidth / 2 - 0.4)
        }
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: max(0.0001, displayed))
            .stroke(
                AngularGradient(
                    colors: arcColors + [arcColors[0]],
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360 * max(0.25, displayed))
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .opacity(fraction > 0 ? 1 : 0)
    }

    /// The Fitness cue: a bright pearl riding the arc's leading tip.
    private var endpointDot: some View {
        GeometryReader { proxy in
            let angle = 2 * .pi * displayed - .pi / 2
            let radius = min(proxy.size.width, proxy.size.height) / 2
            let tip = arcColors.last ?? Theme.accent
            ZStack {
                Circle()
                    .fill(tip)
                    .frame(width: lineWidth * 1.45, height: lineWidth * 1.45)
                    .shadow(color: tip.opacity(0.85), radius: lineWidth * 0.7)
                Circle()
                    .fill(Color.white.opacity(0.92))
                    .frame(width: lineWidth * 0.5, height: lineWidth * 0.5)
            }
            .position(
                x: proxy.size.width / 2 + cos(angle) * radius,
                y: proxy.size.height / 2 + sin(angle) * radius
            )
        }
        .opacity(displayed > 0.02 ? 1 : 0)
    }

    private var arcColors: [Color] {
        gradientOverride ?? Theme.completionColors(fraction: fraction, isPerfect: isPerfect)
    }
}

extension CompletionRing where Center == EmptyView {
    init(
        fraction: Double,
        isPerfect: Bool = false,
        lineWidth: CGFloat = 10,
        animatesOnAppear: Bool = true,
        showsGlow: Bool = true,
        gradientOverride: [Color]? = nil
    ) {
        self.init(
            fraction: fraction,
            isPerfect: isPerfect,
            lineWidth: lineWidth,
            animatesOnAppear: animatesOnAppear,
            showsGlow: showsGlow,
            gradientOverride: gradientOverride
        ) { EmptyView() }
    }
}

#Preview("Rings", traits: .sizeThatFitsLayout) {
    HStack(spacing: 24) {
        CompletionRing(fraction: 0.2, lineWidth: 6)
            .frame(width: 52, height: 52)
        CompletionRing(fraction: 0.55, lineWidth: 8)
            .frame(width: 76, height: 76)
        CompletionRing(fraction: 1.0, isPerfect: true, lineWidth: 10)
            .frame(width: 104, height: 104)
    }
    .padding()
    .background(Color(red: 0.05, green: 0.05, blue: 0.07))
}
