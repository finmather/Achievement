import Foundation
import AchievementCore

/// Everything a signed-in (or demo) session owns. Created fresh on sign-in,
/// discarded on sign-out — no cross-account state can leak.
@Observable @MainActor
final class HomeModel: Identifiable {
    let dataSource: any GameDataSource
    let isDemo: Bool
    let library: LibraryStore
    let friends: FriendsStore
    private(set) var profile: PlayerProfile?

    init(dataSource: any GameDataSource, isDemo: Bool) {
        self.dataSource = dataSource
        self.isDemo = isDemo
        library = LibraryStore(dataSource: dataSource)
        friends = FriendsStore(dataSource: dataSource)
    }

    func start() async {
        async let profileTask: Void = loadProfile()
        async let libraryTask: Void = library.refresh()
        _ = await (profileTask, libraryTask)
    }

    private func loadProfile() async {
        profile = try? await dataSource.profile()
    }
}

@Observable @MainActor
final class AppModel {
    enum Session {
        case restoring
        case signedOut
        case active(HomeModel)
    }

    private static let steamIDKey = "steamID64"
    private static let demoModeKey = "demoMode"

    private(set) var session: Session = .restoring
    private(set) var signInError: String?

    /// Stable identity for cross-fade animations between session states.
    var sessionPhase: String {
        switch session {
        case .restoring: "restoring"
        case .signedOut: "signedOut"
        case .active(let home): home.isDemo ? "demo" : "live"
        }
    }

    func restoreSession() {
        guard case .restoring = session else { return }
        if UserDefaults.standard.bool(forKey: Self.demoModeKey) {
            session = .active(HomeModel(dataSource: DemoGameDataSource(), isDemo: true))
        } else if let raw = KeychainStore.string(for: Self.steamIDKey),
                  let steamID = SteamID(string: raw) {
            activateLive(steamID)
        } else {
            session = .signedOut
        }
    }

    func startDemo() {
        UserDefaults.standard.set(true, forKey: Self.demoModeKey)
        session = .active(HomeModel(dataSource: DemoGameDataSource(), isDemo: true))
    }

    /// Called with the intercepted OpenID redirect. Verifies with Steam
    /// before trusting the SteamID it names.
    func completeSignIn(callback: URL) async {
        do {
            let steamID = try await SteamAuthenticator().validateCallback(callback)
            KeychainStore.set(String(steamID.rawValue), for: Self.steamIDKey)
            UserDefaults.standard.set(false, forKey: Self.demoModeKey)
            signInError = nil
            activateLive(steamID)
        } catch {
            signInError = (error as? SteamAuthError)?.errorDescription
                ?? "Sign-in didn't complete. Please try again."
        }
    }

    func signOut() {
        let home: HomeModel? = {
            if case .active(let model) = session { return model }
            return nil
        }()
        KeychainStore.delete(Self.steamIDKey)
        UserDefaults.standard.set(false, forKey: Self.demoModeKey)
        session = .signedOut
        Task { await home?.library.clearLocalData() }
    }

    private func activateLive(_ steamID: SteamID) {
        let dataSource = LiveGameDataSource(player: steamID, apiKey: AppConfig.steamAPIKey)
        session = .active(HomeModel(dataSource: dataSource, isDemo: false))
    }
}
