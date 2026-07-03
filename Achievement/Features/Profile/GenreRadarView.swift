import SwiftUI
import AchievementCore

/// The app's signature visual: a hexagonal radar of the player's six genre
/// strengths. The polygon springs outward from the center on first
/// appearance; each vertex is tappable and reveals the stats behind it.
struct GenreRadarView: View {
    let profile: GenreProfile

    @State private var expansion: Double = 0
    @State private var selected: GenreAxis?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let size: CGFloat = 300

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RadarWeb()
                    .stroke(.primary.opacity(0.14), lineWidth: 0.8)

                if !profile.isEmpty {
                    RadarPolygon(scores: scores, expansion: expansion)
                        .fill(Theme.accent.opacity(0.22))
                    RadarPolygon(scores: scores, expansion: expansion)
                        .stroke(Theme.accentDuotone, lineWidth: 2)
                        .shadow(color: Theme.accent.opacity(0.5), radius: 10)

                    vertexDots
                }

                axisLabels
            }
            .frame(width: size, height: size)
            .onAppear {
                guard expansion == 0 else { return }
                if reduceMotion {
                    expansion = 1
                    selected = profile.strongest?.axis
                    return
                }
                withAnimation(.spring(duration: 1.0, bounce: 0.3).delay(0.25)) {
                    expansion = 1
                }
                // Once the shape has landed, spotlight the strongest axis.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                    withAnimation(.spring(duration: 0.4)) {
                        selected = profile.strongest?.axis
                    }
                }
            }

            detail
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Genre radar")
        .accessibilityValue(accessibilitySummary)
    }

    private var scores: [Double] {
        profile.axes.map(\.score)
    }

    // MARK: - Vertices & labels

    private var vertexDots: some View {
        ForEach(profile.axes, id: \.axis) { axisScore in
            let point = vertexPoint(for: axisScore)
            let isSelected = selected == axisScore.axis
            Circle()
                .fill(isSelected ? AnyShapeStyle(Theme.accentDuotone)
                                 : AnyShapeStyle(Color.primary.opacity(0.45)))
                .frame(width: isSelected ? 14 : 9, height: isSelected ? 14 : 9)
                .shadow(color: Theme.accent.opacity(isSelected ? 0.8 : 0), radius: 7)
                // Generous invisible tap target around the small dot.
                .contentShape(Circle().inset(by: -18))
                .onTapGesture {
                    Haptics.lightTap()
                    withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                        selected = axisScore.axis
                    }
                }
                .position(point)
        }
    }

    private var axisLabels: some View {
        ForEach(Array(profile.axes.enumerated()), id: \.element.axis) { index, axisScore in
            Text(axisScore.axis.displayName)
                .font(.caption2.weight(selected == axisScore.axis ? .bold : .semibold))
                .foregroundStyle(selected == axisScore.axis ? Theme.accent : .secondary)
                .position(RadarGeometry.point(
                    center: CGPoint(x: size / 2, y: size / 2),
                    index: index,
                    radius: Double(size / 2 - 16)
                ))
                .onTapGesture {
                    Haptics.lightTap()
                    withAnimation(.spring(duration: 0.35, bounce: 0.4)) {
                        selected = axisScore.axis
                    }
                }
        }
    }

    private func vertexPoint(for axisScore: GenreAxisScore) -> CGPoint {
        let index = profile.axes.firstIndex { $0.axis == axisScore.axis } ?? 0
        return RadarGeometry.point(
            center: CGPoint(x: size / 2, y: size / 2),
            index: index,
            radius: Double(size / 2 - 42) * axisScore.score * expansion
        )
    }

    // MARK: - Detail reveal

    @ViewBuilder
    private var detail: some View {
        if profile.isEmpty {
            Text("Play a little more and your shape appears here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if let selected,
                  let axisScore = profile.axes.first(where: { $0.axis == selected }) {
            HStack(spacing: 12) {
                Text(axisScore.axis.displayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.accent)

                if axisScore.gameCount > 0 {
                    Text(detailLine(for: axisScore))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Unexplored territory")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .glassChip()
            .transition(.opacity.combined(with: .scale(scale: 0.92)))
            .id(selected)
        } else {
            Text("Tap a point to explore")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }

    private func detailLine(for axisScore: GenreAxisScore) -> String {
        var parts = ["\(Int(axisScore.hours.rounded())) hrs"]
        parts.append(axisScore.gameCount == 1 ? "1 game" : "\(axisScore.gameCount) games")
        if let top = axisScore.topGame {
            parts.append("mostly \(top.name)")
        }
        return parts.joined(separator: " · ")
    }

    private var accessibilitySummary: String {
        profile.axes
            .map { "\($0.axis.displayName) \(Int(($0.score * 100).rounded())) percent" }
            .joined(separator: ", ")
    }
}

// MARK: - Geometry

private enum RadarGeometry {
    /// Axis 0 points straight up; the rest follow clockwise every 60°.
    /// Double (not CGFloat) so `cos`/`sin` resolve unambiguously.
    static func angle(for index: Int) -> Double {
        -Double.pi / 2 + Double(index) * .pi / 3
    }

    /// A vertex at `radius` along axis `index` from `center`.
    static func point(center: CGPoint, index: Int, radius: Double) -> CGPoint {
        let angle = angle(for: index)
        return CGPoint(
            x: center.x + CGFloat(cos(angle) * radius),
            y: center.y + CGFloat(sin(angle) * radius)
        )
    }
}

/// Concentric hexagon rings plus spokes.
private struct RadarWeb: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = Double(min(rect.width, rect.height) / 2 - 42)

        for level in [0.33, 0.66, 1.0] {
            let radius = maxRadius * level
            for index in 0...6 {
                let point = RadarGeometry.point(
                    center: center, index: index % 6, radius: radius
                )
                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }

        for index in 0..<6 {
            path.move(to: center)
            path.addLine(to: RadarGeometry.point(
                center: center, index: index, radius: maxRadius
            ))
        }
        return path
    }
}

/// The player's shape. `expansion` animates 0→1 so the polygon springs
/// outward from the center.
private struct RadarPolygon: Shape {
    var scores: [Double]
    var expansion: Double

    var animatableData: Double {
        get { expansion }
        set { expansion = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = Double(min(rect.width, rect.height) / 2 - 42)

        for (index, score) in scores.enumerated() {
            // A floor keeps zero axes visible as a dimple, not a spike hole.
            let point = RadarGeometry.point(
                center: center,
                index: index,
                radius: maxRadius * max(0.04, score) * expansion
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

#Preview {
    GenreRadarView(
        profile: GenreEngine.profile(
            games: SampleData.games(),
            tagsByApp: SampleData.genreTags
        )
    )
    .padding()
}
