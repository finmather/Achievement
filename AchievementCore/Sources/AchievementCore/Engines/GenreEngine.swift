import Foundation

/// The six axes of the profile radar chart.
public enum GenreAxis: String, CaseIterable, Hashable, Sendable, Codable {
    case rpg
    case roguelike
    case strategy
    case fps
    case puzzle
    case platformer

    public var displayName: String {
        switch self {
        case .rpg: "RPG"
        case .roguelike: "Roguelike"
        case .strategy: "Strategy"
        case .fps: "FPS"
        case .puzzle: "Puzzle"
        case .platformer: "Platformer"
        }
    }
}

/// One radar vertex: normalized strength plus the stats revealed on tap.
public struct GenreAxisScore: Hashable, Sendable {
    public let axis: GenreAxis
    /// 0...1, normalized against the player's strongest axis.
    public let score: Double
    public let hours: Double
    public let gameCount: Int
    public let topGame: Game?

    public init(axis: GenreAxis, score: Double, hours: Double, gameCount: Int, topGame: Game?) {
        self.axis = axis
        self.score = score
        self.hours = hours
        self.gameCount = gameCount
        self.topGame = topGame
    }
}

/// The full radar: always all six axes, in `GenreAxis.allCases` order.
public struct GenreProfile: Hashable, Sendable {
    public let axes: [GenreAxisScore]

    public init(axes: [GenreAxisScore]) {
        self.axes = axes
    }

    public var isEmpty: Bool {
        axes.allSatisfy { $0.score == 0 }
    }

    public var strongest: GenreAxisScore? {
        let best = axes.max { $0.score < $1.score }
        return (best?.score ?? 0) > 0 ? best : nil
    }
}

/// Turns community tags + play data into the radar profile.
///
/// Scoring: each played game with mapped tags contributes
/// `sqrt(hours) + 0.2·sqrt(unlocked achievements)` to every axis its tags
/// touch. Square roots stop a single 200-hour game from flattening the
/// hexagon. Scores normalize so the strongest axis is 1.0.
public enum GenreEngine {
    public static func profile(games: [Game], tagsByApp: [Int: [String]]) -> GenreProfile {
        struct Accumulator {
            var weight = 0.0
            var hours = 0.0
            var count = 0
            var top: Game?
        }
        var byAxis: [GenreAxis: Accumulator] = [:]

        for game in games where game.playtimeMinutes > 0 {
            guard let tags = tagsByApp[game.appID] else { continue }
            let matchedAxes = Set(tags.flatMap { Self.axes(forTag: $0) })
            guard !matchedAxes.isEmpty else { continue }

            let hours = game.hoursPlayed
            let unlocked = Double(game.achievements?.unlocked ?? 0)
            let weight = hours.squareRoot() + 0.2 * unlocked.squareRoot()

            for axis in matchedAxes {
                var acc = byAxis[axis, default: Accumulator()]
                acc.weight += weight
                acc.hours += hours
                acc.count += 1
                if hours > (acc.top?.hoursPlayed ?? -1) { acc.top = game }
                byAxis[axis] = acc
            }
        }

        let maxWeight = byAxis.values.map(\.weight).max() ?? 0
        let axes = GenreAxis.allCases.map { axis in
            let acc = byAxis[axis] ?? .init()
            return GenreAxisScore(
                axis: axis,
                score: maxWeight > 0 ? acc.weight / maxWeight : 0,
                hours: acc.hours,
                gameCount: acc.count,
                topGame: acc.top
            )
        }
        return GenreProfile(axes: axes)
    }

    /// Which axes a single community tag feeds (a tag may feed several,
    /// e.g. "puzzle platformer"). Case-insensitive.
    public static func axes(forTag tag: String) -> [GenreAxis] {
        mapping[tag.lowercased().trimmingCharacters(in: .whitespaces)] ?? []
    }

    private static let mapping: [String: [GenreAxis]] = [
        "rpg": [.rpg], "action rpg": [.rpg], "action-rpg": [.rpg],
        "jrpg": [.rpg], "crpg": [.rpg], "role-playing": [.rpg],
        "souls-like": [.rpg], "soulslike": [.rpg], "dungeon crawler": [.rpg],
        "party-based rpg": [.rpg], "strategy rpg": [.rpg, .strategy],
        "open world rpg": [.rpg],

        "roguelike": [.roguelike], "rogue-like": [.roguelike],
        "roguelite": [.roguelike], "rogue-lite": [.roguelike],
        "action roguelike": [.roguelike], "traditional roguelike": [.roguelike],
        "roguelike deckbuilder": [.roguelike, .strategy],
        "roguevania": [.roguelike, .platformer],

        "strategy": [.strategy], "turn-based strategy": [.strategy],
        "real time strategy": [.strategy], "rts": [.strategy],
        "grand strategy": [.strategy], "4x": [.strategy],
        "tactical": [.strategy], "turn-based tactics": [.strategy],
        "tower defense": [.strategy], "deckbuilding": [.strategy],
        "deck-building": [.strategy], "card battler": [.strategy],
        "card game": [.strategy], "auto battler": [.strategy],

        "fps": [.fps], "shooter": [.fps], "first-person shooter": [.fps],
        "third-person shooter": [.fps], "arena shooter": [.fps],
        "boomer shooter": [.fps], "looter shooter": [.fps],
        "hero shooter": [.fps], "tactical shooter": [.fps],
        "bullet hell": [.fps], "top-down shooter": [.fps],

        "puzzle": [.puzzle], "logic": [.puzzle], "point & click": [.puzzle],
        "hidden object": [.puzzle], "match 3": [.puzzle], "sokoban": [.puzzle],
        "puzzle platformer": [.puzzle, .platformer],
        "puzzle-platformer": [.puzzle, .platformer],

        "platformer": [.platformer], "2d platformer": [.platformer],
        "3d platformer": [.platformer], "precision platformer": [.platformer],
        "metroidvania": [.platformer], "side scroller": [.platformer],
    ]
}
