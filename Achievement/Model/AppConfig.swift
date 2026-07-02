import Foundation

enum AppConfig {
    /// Injected from Config/Secrets.xcconfig via Info.plist. Empty when the
    /// developer hasn't added a key yet — the app degrades to a clear,
    /// actionable error instead of failing mysteriously.
    static var steamAPIKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SteamAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// OpenID redirect target. It never actually loads — the sign-in web view
    /// intercepts navigation to it — so the domain only needs to be unique.
    static let openIDReturnTo = URL(string: "https://achievement.app/auth/steam")!
    static let openIDRealm = URL(string: "https://achievement.app")!

    static var cacheDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "LibraryCache")
    }
}
