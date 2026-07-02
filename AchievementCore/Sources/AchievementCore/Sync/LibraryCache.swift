import Foundation

/// JSON-on-disk persistence for the synced library. Everything the app shows
/// is renderable from this cache, which is what makes launches instant and
/// sync a background refinement rather than a blocking load.
public actor LibraryCache {
    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    /// - Parameter directory: usually
    ///   `.applicationSupportDirectory/Library`, injectable for tests.
    public init(directory: URL) {
        self.directory = directory
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    // MARK: - Typed accessors

    public func games() -> [Game]? {
        load([Game].self, "games.json")
    }

    public func storeGames(_ games: [Game]) {
        save(games, "games.json")
    }

    public func profile() -> PlayerProfile? {
        load(PlayerProfile.self, "profile.json")
    }

    public func storeProfile(_ profile: PlayerProfile) {
        save(profile, "profile.json")
    }

    public func friends() -> [PlayerProfile]? {
        load([PlayerProfile].self, "friends.json")
    }

    public func storeFriends(_ friends: [PlayerProfile]) {
        save(friends, "friends.json")
    }

    /// `nil` means never fetched; an empty array means "fetched, game has no
    /// achievements" — the distinction keeps SyncPlanner from refetching.
    public func achievements(appID: Int) -> [Achievement]? {
        load([Achievement].self, achievementsName(appID))
    }

    public func storeAchievements(_ achievements: [Achievement], appID: Int) {
        save(achievements, achievementsName(appID))
    }

    public func hydratedAppIDs() -> Set<Int> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        return Set(names.compactMap { name in
            guard name.hasPrefix("achievements-"), name.hasSuffix(".json") else { return nil }
            return Int(name.dropFirst("achievements-".count).dropLast(".json".count))
        })
    }

    /// Wipes everything — used on sign-out.
    public func clear() {
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - Plumbing

    private func achievementsName(_ appID: Int) -> String {
        "achievements-\(appID).json"
    }

    private func load<T: Decodable>(_ type: T.Type, _ name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ name: String) {
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            let data = try encoder.encode(value)
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        } catch {
            // Cache writes are best-effort; the source of truth is Steam.
        }
    }
}
