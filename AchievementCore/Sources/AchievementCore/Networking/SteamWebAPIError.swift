import Foundation

public enum SteamWebAPIError: Error, Equatable, Sendable {
    /// No API key configured — see Config/Secrets.example.xcconfig.
    case missingAPIKey
    /// The player's profile or game details are private.
    case profilePrivate
    /// The requested app exposes no achievement stats.
    case noAchievements
    case rateLimited
    case httpStatus(Int)
    case invalidResponse
}

extension SteamWebAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "No Steam Web API key is configured."
        case .profilePrivate:
            "This Steam profile is private. Game details must be set to public in Steam privacy settings."
        case .noAchievements:
            "This game has no achievements."
        case .rateLimited:
            "Steam is limiting requests right now. Try again in a moment."
        case .httpStatus(let code):
            "Steam returned an unexpected response (\(code))."
        case .invalidResponse:
            "Steam returned a response that couldn't be read."
        }
    }
}
