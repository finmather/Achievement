import XCTest

/// Walks every screen in demo mode and attaches a screenshot of each. CI
/// runs this twice (dark, then light) and records the dark walk as video —
/// this project is authored on Windows, so these artifacts *are* the design
/// review.
///
/// One test, one launch: the celebration fires at startup (via launch env)
/// and is captured first, so the walk never needs to relaunch the app —
/// XCUITest's terminate-and-relaunch flakes on actively-animating apps.
final class AchievementScreenshotTests: XCTestCase {
    override func tearDown() {
        XCUIApplication().terminate()
        super.tearDown()
    }

    func testCaptureAllScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TEST_DEMO_MODE"] = "1"
        app.launchEnvironment["UI_TEST_CELEBRATE"] = "1"
        app.launch()

        // The unlock celebration greets us shortly after launch.
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 25),
                      "celebration overlay never settled")
        sleep(1) // embers mid-drift
        capture(app, name: "00-celebration")
        continueButton.tap()
        sleep(1)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "no tab bar after celebration")
        sleep(2) // entrance stagger + hero arc sweep
        capture(app, name: "01-dashboard")

        tabBar.buttons["Library"].tap()
        sleep(2)
        capture(app, name: "02-library")

        let firstCover = app.buttons.matching(identifier: "library.cover").firstMatch
        if firstCover.waitForExistence(timeout: 5) {
            firstCover.tap()
            sleep(2)
            capture(app, name: "03-game-detail")
            app.swipeUp()
            sleep(1)
            capture(app, name: "03b-game-detail-scrolled")
            goBack(app)
        }

        let search = app.textFields["library.search"]
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("zzzz\n") // return dismisses the keyboard
            sleep(1)
            capture(app, name: "04-library-empty-search")
        }

        tabBar.buttons["Friends"].tap()
        sleep(2)
        capture(app, name: "05-friends")

        let firstFriend = app.buttons.matching(identifier: "friends.row").firstMatch
        if firstFriend.waitForExistence(timeout: 5) {
            firstFriend.tap()
            sleep(3) // duel bars animate + shared progress hydrates
            capture(app, name: "06-friend-compare")
            goBack(app)
        }

        tabBar.buttons["Profile"].tap()
        sleep(3) // radar springs out and auto-selects the strongest axis
        capture(app, name: "07-profile-radar")

        app.swipeUp()
        sleep(1)
        capture(app, name: "08-profile-passport")
    }

    /// Back-navigation that can never fail the walk: try the bar button,
    /// fall back to the edge-swipe gesture.
    private func goBack(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.waitForExistence(timeout: 4) {
            back.tap()
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        sleep(1)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
