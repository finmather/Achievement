import SwiftUI

/// First-sync copy written by people who love games — cycles gently under
/// loading skeletons so even waiting has some charm.
struct LoadingQuips: View {
    private static let quips = [
        "Polishing the trophies…",
        "Interrogating Steam, politely…",
        "Counting the uncounted…",
        "Dusting off the backlog…",
        "Negotiating with rare drops…",
        "Alphabetizing your victories…",
    ]

    @State private var index = Int.random(in: 0..<quips.count)

    var body: some View {
        Text(Self.quips[index])
            .font(.footnote)
            .foregroundStyle(.secondary)
            .id(index)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .onReceive(
                Timer.publish(every: 2.6, on: .main, in: .common).autoconnect()
            ) { _ in
                withAnimation(.settle) {
                    index = (index + 1) % Self.quips.count
                }
            }
            .accessibilityLabel("Loading")
    }
}
