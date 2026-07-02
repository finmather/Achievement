import Foundation

/// User-selectable library orderings.
public enum LibrarySort: String, CaseIterable, Identifiable, Sendable, Codable {
    case recentlyPlayed
    case mostCompleted
    case leastCompleted
    case hoursPlayed
    case alphabetical

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .recentlyPlayed: "Recently Played"
        case .mostCompleted: "Most Completed"
        case .leastCompleted: "Least Completed"
        case .hoursPlayed: "Hours Played"
        case .alphabetical: "A to Z"
        }
    }
}

public enum LibraryFilter {
    /// Applies search then sort. Search is case- and diacritic-insensitive;
    /// prefix matches rank ahead of substring matches so results feel instant
    /// and predictable while typing.
    public static func apply(_ games: [Game], search: String, sort: LibrarySort) -> [Game] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted(games, by: sort) }

        var prefixMatches: [Game] = []
        var substringMatches: [Game] = []
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

        for game in games {
            guard let range = game.name.range(of: query, options: options) else { continue }
            if range.lowerBound == game.name.startIndex {
                prefixMatches.append(game)
            } else {
                substringMatches.append(game)
            }
        }
        return sorted(prefixMatches, by: sort) + sorted(substringMatches, by: sort)
    }

    public static func sorted(_ games: [Game], by sort: LibrarySort) -> [Game] {
        switch sort {
        case .alphabetical:
            return games.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        case .hoursPlayed:
            return games.sorted {
                if $0.playtimeMinutes != $1.playtimeMinutes {
                    return $0.playtimeMinutes > $1.playtimeMinutes
                }
                return nameAscending($0, $1)
            }

        case .recentlyPlayed:
            return games.sorted {
                switch ($0.lastPlayed, $1.lastPlayed) {
                case let (a?, b?) where a != b: return a > b
                case (.some, .none): return true
                case (.none, .some): return false
                default:
                    if $0.playtimeMinutes != $1.playtimeMinutes {
                        return $0.playtimeMinutes > $1.playtimeMinutes
                    }
                    return nameAscending($0, $1)
                }
            }

        case .mostCompleted:
            return sortedByCompletion(games, ascending: false)

        case .leastCompleted:
            return sortedByCompletion(games, ascending: true)
        }
    }

    /// Games without achievements always sink to the bottom — for a
    /// completionist they're noise in either completion ordering.
    private static func sortedByCompletion(_ games: [Game], ascending: Bool) -> [Game] {
        let (tracked, untracked) = games.stablePartition {
            ($0.achievements?.total ?? 0) > 0
        }
        let sortedTracked = tracked.sorted { a, b in
            let fa = a.achievements!.fraction
            let fb = b.achievements!.fraction
            if fa != fb { return ascending ? fa < fb : fa > fb }
            let ua = a.achievements!.unlocked
            let ub = b.achievements!.unlocked
            if ua != ub { return ascending ? ua < ub : ua > ub }
            return nameAscending(a, b)
        }
        return sortedTracked + untracked.sorted(by: nameAscending)
    }

    private static func nameAscending(_ a: Game, _ b: Game) -> Bool {
        a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
    }
}

extension Array {
    /// Splits into (matching, non-matching) preserving relative order.
    func stablePartition(_ belongsInFirst: (Element) -> Bool) -> ([Element], [Element]) {
        var first: [Element] = []
        var second: [Element] = []
        for element in self {
            if belongsInFirst(element) { first.append(element) } else { second.append(element) }
        }
        return (first, second)
    }
}
