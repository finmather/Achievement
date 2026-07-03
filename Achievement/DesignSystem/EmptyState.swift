import SwiftUI

/// Empty screens get a small piece of living artwork instead of a shrug:
/// concentric aurora rings, two slowly orbiting motes, and a glass medallion
/// holding the motif. One illustration style everywhere, drawn in code so it
/// adapts to both color schemes and never mismatches.
struct EmptyStateView: View {
    enum Motif {
        case telescope   // searching / nothing found
        case trophy      // achievements
        case controller  // library
        case lock        // privacy walls
        case friends     // social
        case signal      // connectivity

        var symbol: String {
            switch self {
            case .telescope: "binoculars.fill"
            case .trophy: "trophy.fill"
            case .controller: "gamecontroller.fill"
            case .lock: "lock.fill"
            case .friends: "person.2.fill"
            case .signal: "wifi.slash"
            }
        }
    }

    let motif: Motif
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 8) {
            OrbitIllustration(symbol: motif.symbol)
                .frame(width: 150, height: 150)
                .padding(.bottom, 12)
                .entrance(0)

            Text(title)
                .font(.sectionTitle)
                .entrance(1)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 40)
                .entrance(2)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Theme.accentDuotone))
                }
                .buttonStyle(.pressable)
                .padding(.top, 14)
                .entrance(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

/// The shared illustration: rings + orbiting motes + glass medallion.
private struct OrbitIllustration: View {
    let symbol: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                composition(orbit: 0.35)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                    composition(
                        orbit: context.date.timeIntervalSinceReferenceDate * 0.35
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func composition(orbit: Double) -> some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(
                        Theme.accentDuotone,
                        style: StrokeStyle(lineWidth: 1, dash: ring == 2 ? [1, 7] : [])
                    )
                    .opacity(0.22 - Double(ring) * 0.06)
                    .padding(CGFloat(ring) * 22)
            }

            mote(angle: orbit, radius: 75, size: 7, color: Theme.accent)
            mote(angle: orbit * 1.6 + 2.4, radius: 53, size: 5, color: Theme.accentTeal)

            Image(systemName: symbol)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.accentDuotone)
                .frame(width: 68, height: 68)
                .glassChip(.circle)
        }
    }

    private func mote(angle: Double, radius: CGFloat, size: CGFloat, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.8), radius: 4)
            .offset(x: cos(angle) * radius, y: sin(angle) * radius)
    }
}

#Preview {
    EmptyStateView(
        motif: .telescope,
        title: "Nothing out here",
        message: "No games match that search. Try fewer letters — the library searches as you type.",
        actionTitle: "Clear search",
        action: {}
    )
}
