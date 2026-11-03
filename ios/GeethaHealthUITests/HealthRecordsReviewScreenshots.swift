import XCTest

// Generates the Clinical Health Records screenshots sent to App Review
// (ios/AppReview/clinical-health-records-flow/). Apple asked for "the entire
// Clinical Health Records permissions flow, including what users see after CHR
// data has been added to the app".
//
// Not a correctness test. Run it through ios/AppReview/capture-chr-flow.sh,
// which gives each test a fresh install (that is what resets the HealthKit
// grant, so the full system sheet appears) and sets REVIEW_SHOTS_DIR, where the
// PNGs are written. Run any other way, the shots are only attached to the
// result bundle.
//
// The records are Apple's sample Health Records data ("Sample Institution A"),
// which the test connects in the Simulator's Health app if it isn't already.
final class HealthRecordsReviewScreenshots: XCTestCase {

    private var app: XCUIApplication!
    private let health = XCUIApplication(bundleIdentifier: "com.apple.Health")

    override func setUp() {
        continueAfterFailure = false
        connectSampleHealthRecords()
        app = XCUIApplication()
        app.launch()
        completeOnboardingIfNeeded()
    }

    func testCaptureGrantFlow() {
        // The entry point sits below the fold, behind the tab bar.
        app.swipeUp()
        snap("01-Records-tab-Import-from-Apple-Health")
        app.buttons["Import from Apple Health"].tap()

        // Apple's system sheet: an intro page, then steps 1–4.
        tapNext(after: "02-Apple-sheet-How-Sharing-Works")
        tapNext(after: "03-Apple-sheet-1of4-Choose-accounts")
        tapNext(after: "04-Apple-sheet-2of4-You-Should-Know")

        for category in ["Allergies", "Conditions", "Immunizations", "Medications"] {
            let toggle = app.switches["UIA.Health.\(category).SwitchCell.Switch"]
            XCTAssertTrue(toggle.waitForExistence(timeout: 5), "\(category) switch missing")
            if toggle.value as? String == "0" { toggle.tap() }
        }
        snap("05-Apple-sheet-3of4-Choose-categories")
        app.buttons["Share"].firstMatch.tap()

        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        snap("06-Apple-sheet-4of4-New-records")
        done.tap()

        // Our import preview. Scrolled so every candidate is in frame.
        let previewNote = "Records stay on this device. Already-imported records are skipped automatically."
        XCTAssertTrue(app.staticTexts[previewNote].waitForExistence(timeout: 15))
        app.swipeUp()
        snap("07-Import-preview-user-selects-records")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Import '")).firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 10))
        app.swipeDown()
        snap("08-Records-tab-after-import")

        openList("Conditions")
        snap("09-Imported-conditions")
        // Tapping a record opens it in an edit sheet.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Asthma'")).firstMatch.tap()
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        snap("10-Imported-record-opened")
        cancel.tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 5))
        back()

        openList("Medications")
        snap("11-Imported-medications")
        back()

        openList("Allergies")
        snap("12-Imported-allergies")
        back()

        // Where the user reviews or turns off access afterwards.
        health.launch()
        openHealthRecordsSettings()
        snap("13-Health-app-Health-Records-Apps")
        health.cells["UIA.Health.HealthRecordsSettings.AppCell.0"].tap()
        XCTAssertTrue(health.navigationBars["Geetha Health"].waitForExistence(timeout: 5))
        snap("14-Health-app-turn-off-access")
    }

    func testCaptureDeclinePath() {
        app.swipeUp()
        app.buttons["Import from Apple Health"].tap()
        for _ in 0..<3 { tapNext() }

        let dontShare = app.buttons["Don’t Share"].firstMatch
        XCTAssertTrue(dontShare.waitForExistence(timeout: 5))
        dontShare.tap()
        XCTAssertTrue(app.staticTexts["No health records found"].waitForExistence(timeout: 10))
        snap("15-Declined-Dont-Share-nothing-imported")
    }

    // MARK: - Setup

    private func completeOnboardingIfNeeded() {
        let firstName = app.textFields["First name"]
        if firstName.waitForExistence(timeout: 10) {
            firstName.tap()
            firstName.typeText("Alex")
            let lastName = app.textFields["Last name"]
            lastName.tap()
            lastName.typeText("Rivera")
            app.buttons["Get started"].tap()
        }
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 10),
                      "Did not reach Records after onboarding")
    }

    /// Connects Apple's sample provider in the Health app, walking Health's own
    /// first-run screens on a freshly erased Simulator. A no-op once connected.
    private func connectSampleHealthRecords() {
        health.launch()
        openHealthProfile()
        tap(health.cells["UIA.Health.ShowHealthRecords"])
        if !health.cells["UIA.Health.HealthRecordsSettings.AccountCell.0"].waitForExistence(timeout: 3) {
            // Searching providers asks for location; capture-chr-flow.sh
            // pre-grants it so no alert appears.
            tap(health.buttons["Get Started"].firstMatch)
            tap(health.cells["UIA.Health.ClinicalOnboarding.Suggestions.SampleInstitutionA.tableCell"])
            tap(health.buttons["UIA.Health.ClinicalOnboarding.Gateway.ConnectAccount"])
            tap(health.buttons["UIA.Health.ClinicalOnboarding.AccountAdded.DoneButton"], timeout: 30)
        }
        health.terminate()
    }

    // MARK: - Helpers

    /// Health shows its first-run screens on the first visit to Profile, and
    /// can show them again on the next launch if it was terminated before
    /// saving that they were seen.
    private func openHealthProfile() {
        health.buttons["Profile"].firstMatch.tap()
        let welcome = health.buttons["UIA.Health.BuddyOnboarding.WelcomeScreen.ContinueButton"]
        if welcome.waitForExistence(timeout: 5) {
            welcome.tap()
            tap(health.buttons["UIA.Health.BuddyOnboarding.PrivacyScreen.ContinueButton"])
            tap(health.buttons["Next"].firstMatch)
            tap(health.buttons["UIA.Health.BuddyOnboarding.NotificationScreen.ContinueButton"])
            health.buttons["Profile"].firstMatch.tap()
        }
    }

    private func openHealthRecordsSettings() {
        openHealthProfile()
        tap(health.cells["UIA.Health.ShowHealthRecords"])
        XCTAssertTrue(health.cells["UIA.Health.HealthRecordsSettings.AppCell.0"].waitForExistence(timeout: 5))
    }

    private func tapNext(after shot: String? = nil) {
        let next = app.buttons["Next"].firstMatch
        XCTAssertTrue(next.waitForExistence(timeout: 10), "System sheet Next button missing")
        if let shot { snap(shot) }
        next.tap()
    }

    private func openList(_ name: String) {
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), "Did not open \(name)")
    }

    private func back() {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 5))
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 10) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "\(element) missing")
        element.tap()
    }

    /// Lets sheet and navigation animations settle, then captures the screen.
    private func snap(_ name: String) {
        sleep(2)
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["REVIEW_SHOTS_DIR"] {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
    }
}
