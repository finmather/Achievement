import Foundation

/// Basic public profile information for a Steam account.
public struct PlayerProfile: Identifiable, Hashable, Sendable, Codable {
    public let id: SteamID
    public var personaName: String
    public var realName: String?
    public var avatarSmallURL: URL?
    public var avatarFullURL: URL?
    public var profileURL: URL?
    public var countryCode: String?
    public var accountCreatedAt: Date?
    /// `false` when the profile (and therefore game/achievement data) is private.
    public var isPublic: Bool

    public init(
        id: SteamID,
        personaName: String,
        realName: String? = nil,
        avatarSmallURL: URL? = nil,
        avatarFullURL: URL? = nil,
        profileURL: URL? = nil,
        countryCode: String? = nil,
        accountCreatedAt: Date? = nil,
        isPublic: Bool = true
    ) {
        self.id = id
        self.personaName = personaName
        self.realName = realName
        self.avatarSmallURL = avatarSmallURL
        self.avatarFullURL = avatarFullURL
        self.profileURL = profileURL
        self.countryCode = countryCode
        self.accountCreatedAt = accountCreatedAt
        self.isPublic = isPublic
    }
}
