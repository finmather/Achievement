import SwiftUI

@main
struct AchievementApp: App {
    @State private var model = AppModel()

    init() {
        // Art-heavy app: give the shared cache room so covers and icons
        // survive relaunches without refetching.
        URLCache.shared = URLCache(
            memoryCapacity: 40 * 1024 * 1024,
            diskCapacity: 150 * 1024 * 1024
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(Theme.accent)
        }
    }
}
