import Foundation

/// "More like this from your library": ranks the player's own games by tag
/// affinity with a reference game. Exact tag matches weigh by how prominent
/// the tag is (community vote order); sharing a radar axis adds a smaller
/// genre-level bonus.
public enum SimilarGames {
    public static func similar(
        to game: Game,
        in library: [Game],
        tagsByApp: [Int: [String]],
        limit: Int = 4
    ) -> [Game] {
        guard let baseTags = tagsByApp[game.appID], !baseTags.isEmpty else { return [] }
        let baseSet = Set(baseTags.map { $0.lowercased() })
        let baseAxes = Set(baseTags.flatMap(GenreEngine.axes(forTag:)))

        let scored: [(game: Game, score: Double)] = library.compactMap { other in
            guard other.appID != game.appID,
                  let tags = tagsByApp[other.appID], !tags.isEmpty else { return nil }

            var score = 0.0
            for (rank, tag) in tags.enumerated() where baseSet.contains(tag.lowercased()) {
                score += 3.0 / Double(rank + 1)
            }
            let sharedAxes = Set(tags.flatMap(GenreEngine.axes(forTag:)))
                .intersection(baseAxes)
            score += Double(sharedAxes.count) * 0.75

            return score > 0 ? (other, score) : nil
        }

        return scored
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.game.name.localizedCaseInsensitiveCompare($1.game.name)
                    == .orderedAscending
            }
            .prefix(limit)
            .map(\.game)
    }
}
