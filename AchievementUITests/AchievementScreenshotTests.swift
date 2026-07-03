import XCTest

/// Walks every screen in demo mode and attaches a screenshot of each. CI
/// runs this twice (dark, then light) and also records the whole walk as
/// video for frame-by-frame motion review — this project is authored on
/// Windows, so these artifacts *are* the design review.
///
/// Sleeps are deliberate: entrance choreography, ring sweeps, and the radar
/// spring need to settle before a still is worth reviewing.
final class AchievementScreenshotTests: XCTestCase {
    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_DEMO_MODE"] = "1"
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 20), "app did not reach the main tabs")
        sleep(3) // demo load + entrance stagger + hero arc sweep
        capture(app, name: "01-dashboard")

        // Library: cover wall, zoom into detail, then the empty search state.
        tabBar.buttons["Library"].tap()
        sleep(2)
        capture(app, name: "02-library")

        let firstCover = app.scrollViews.firstMatch.buttons.firstMatch
        if firstCover.waitForExistence(timeout: 5) {
            firstCover.tap()
            sleep(2) // zoom transition + backdrop bloom
            capture(app, name: "03-game-detail")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        let search = app.textFields["library.search"]
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("zzzz\n") // return dismisses the keyboard
            sleep(1)
            capture(app, name: "04-library-empty-search")
            app.buttons["Clear search"].tap()
            sleep(1)
        }

        tabBar.buttons["Friends"].tap()
        sleep(2)
        capture(app, name: "05-friends")

        let firstFriend = app.scrollViews.firstMatch.buttons.firstMatch
        if firstFriend.waitForExistence(timeout: 5) {
            firstFriend.tap()
            sleep(3) // duel bars animate + shared progress hydrates
            capture(app, name: "06-friend-compare")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }

        tabBar.buttons["Profile"].tap()
        sleep(3) // radar springs out and auto-selects the strongest axis
        capture(app, name: "07-profile-radar")

        app.swipeUp()
        sleep(1)
        capture(app, name: "08-profile-passport")
    }

    func testCaptureCelebration() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_DEMO_MODE"] = "1"
        app.launchEnvironment["UI_TEST_CELEBRATE"] = "1"
        app.launch()

        // The celebration fires shortly after the library loads; its
        // Continue button appears once the choreography settles.
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 25),
                      "celebration overlay never settled")
        sleep(1) // embers mid-drift
        capture(app, name: "09-celebration")
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
