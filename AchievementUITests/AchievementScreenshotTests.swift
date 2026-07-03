import XCTest

/// Walks every screen in demo mode and attaches a screenshot of each.
/// Run via the `AchievementScreenshots` scheme; CI extracts the attachments
/// from the resulting .xcresult with xcparse. `UI_TEST_DEMO_MODE=1` makes
/// the app skip onboarding and launch straight into demo data, so this
/// needs no simulated sign-in.
final class AchievementScreenshotTests: XCTestCase {
    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_DEMO_MODE"] = "1"
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "app did not reach the main tab view")

        capture(app, name: "01-dashboard")

        tabBar.buttons["Library"].tap()
        _ = app.scrollViews.firstMatch.waitForExistence(timeout: 5)
        capture(app, name: "02-library")

        let firstGameCard = app.scrollViews.firstMatch.buttons.firstMatch
        if firstGameCard.waitForExistence(timeout: 5) {
            firstGameCard.tap()
            sleep(1)
            capture(app, name: "03-game-detail")
            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3) {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }

        tabBar.buttons["Friends"].tap()
        sleep(1)
        capture(app, name: "04-friends")

        let firstFriendRow = app.scrollViews.firstMatch.buttons.firstMatch
        if firstFriendRow.waitForExistence(timeout: 5) {
            firstFriendRow.tap()
            sleep(2) // comparison hydrates progressively; give it a moment
            capture(app, name: "05-friend-compare")
            if app.navigationBars.buttons.firstMatch.waitForExistence(timeout: 3) {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }

        tabBar.buttons["Profile"].tap()
        sleep(1)
        capture(app, name: "06-profile")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
