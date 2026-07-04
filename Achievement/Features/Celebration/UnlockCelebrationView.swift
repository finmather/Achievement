import SwiftUI
import AchievementCore

/// The moment the app exists for. Choreography, in order:
///
/// 1. The world dims and the aurora brightens toward celebration.
/// 2. A rarity-colored glow blooms as the achievement icon springs up from
///    nothing with a slight overshoot (soft haptic on bloom, firm on landing).
/// 3. Fine luminous motes drift outward — embers, not confetti.
/// 4. Title, game, and rarity settle in, staggered.
///
/// Premium restraint: slow particles, one glow, no shaking or starbursts.
struct UnlockCelebrationView: View {
    let unlock: UnlockEvent
    var extraCount: Int = 0
    let onDismiss: () -> Void

    @State private var bloomed = false
    @State private var landed = false
    @State private var settled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rarityColor: Color {
        unlock.achievement.rarity.map(Theme.color(for:)) ?? Theme.accent
    }

    var body: some View {
        ZStack {
            AmbientBackground(palette: .celebration)
                .opacity(bloomed ? 1 : 0)
            Color.black
                .opacity(bloomed ? 0.42 : 0)
                .ignoresSafeArea()

            if bloomed && !reduceMotion {
                EmberField(tint: rarityColor)
            }

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(rarityColor.opacity(0.5))
                        .frame(width: 190, height: 190)
                        .blur(radius: 46)
                        .scaleEffect(landed ? 1 : 0.2)

                    AchievementIcon(achievement: unlock.achievement, size: 104)
                        .scaleEffect(landed ? 1 : (bloomed ? 1.14 : 0.01))
                        .shadow(color: rarityColor.opacity(0.6), radius: 24)
                }
                .padding(.bottom, 34)

                Group {
                    Text("Achievement unlocked").capsLabel()
                        .padding(.bottom, 10)

                    Text(unlock.achievement.displayName)
                        .font(.editorialTitle)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .lineLimit(3)
                        .padding(.horizontal, 36)
                        .padding(.bottom, 14)

                    HStack(spacing: 10) {
                        if let rarity = unlock.achievement.rarity {
                            RarityChip(rarity: rarity)
                        }
                        Text(unlock.gameName)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    if extraCount > 0 {
                        Text(extraCount == 1 ? "and 1 more today" : "and \(extraCount) more today")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                    }
                }
                .opacity(settled ? 1 : 0)
                .offset(y: settled ? 0 : 16)

                Spacer()

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 13)
                        .glassChip()
                }
                .buttonStyle(.pressable)
                .opacity(settled ? 1 : 0)
                .padding(.bottom, 56)
            }
            .foregroundStyle(.white)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if settled { onDismiss() }
        }
        .onAppear(perform: choreograph)
        .accessibilityAddTraits(.isModal)
    }

    private func choreograph() {
        if reduceMotion {
            bloomed = true
            landed = true
            settled = true
            Haptics.success()
            return
        }
        withAnimation(.easeOut(duration: 0.35)) { bloomed = true }
        Haptics.lightTap()
        withAnimation(.spring(duration: 0.65, bounce: 0.42).delay(0.2)) { landed = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Haptics.celebrate()
        }
        withAnimation(.spring(duration: 0.6, bounce: 0.2).delay(0.75)) { settled = true }
    }
}

/// Slow luminous motes rising and fading from the icon's position.
private struct EmberField: View {
    let tint: Color
    @State private var born = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40)) { context in
            Canvas { canvas, size in
                let age = context.date.timeIntervalSince(born)
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.42)

                for index in 0..<38 {
                    // Cheap deterministic per-mote randomness.
                    let h1 = Double((index &* 2_654_435_761) % 1000) / 1000
                    let h2 = Double((index &* 40_503) % 1000) / 1000
                    let h3 = Double((index &* 69_069) % 1000) / 1000

                    let delay = h3 * 1.4
                    let t = age - 0.25 - delay
                    guard t > 0 else { continue }

                    let life = 2.2 + h1 * 1.6
                    let progress = t / life
                    guard progress < 1 else { continue }

                    let angle = h1 * .pi * 2
                    let speed = 34 + h2 * 58
                    let x = origin.x + cos(angle) * speed * t
                    let y = origin.y + sin(angle) * speed * t - 26 * t // ember rise
                    let alpha = (1 - progress) * 0.85
                    let radius = 1.4 + h2 * 2.2

                    canvas.fill(
                        Path(ellipseIn: CGRect(
                            x: x - radius, y: y - radius,
                            width: radius * 2, height: radius * 2
                        )),
                        with: .color(tint.opacity(alpha))
                    )
                }

                // Four slow golden sparks with short comet tails — garnish,
                // not fireworks.
                let sparkGold = Color(red: 0.98, green: 0.78, blue: 0.32)
                if age > 0.7 {
                    for spark in 0..<4 {
                        let cycle = (age * 0.2 + Double(spark) * 0.25)
                            .truncatingRemainder(dividingBy: 1)
                        let angle = Double(spark) * 1.65 + 0.5
                        let distance = 46 + cycle * 160
                        let alpha = (1 - cycle) * 0.55

                        for segment in 0..<3 {
                            let trail = Double(segment) * 9
                            let sx = origin.x + cos(angle) * (distance - trail)
                            let sy = origin.y + sin(angle) * (distance - trail) - 14 * cycle
                            let r = (2.0 - Double(segment) * 0.55) * (1 - cycle * 0.4)
                            canvas.fill(
                                Path(ellipseIn: CGRect(
                                    x: sx - r, y: sy - r, width: r * 2, height: r * 2
                                )),
                                with: .color(sparkGold.opacity(alpha * (1 - Double(segment) * 0.3)))
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

#Preview {
    UnlockCelebrationView(
        unlock: SampleData.allUnlocks().first!,
        extraCount: 2,
        onDismiss: {}
    )
}
