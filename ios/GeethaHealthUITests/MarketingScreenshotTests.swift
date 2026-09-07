import XCTest

// Generates the screenshots used on the marketing site (docs/assets/shot-*.png).
//
// Not a correctness test — it seeds a fictional profile, walks the screens we
// advertise, and attaches a screenshot of each. Kept in the repo so the site's
// screenshots can be regenerated after a UI change instead of being re-shot by
// hand and slowly drifting out of date.
//
//   xcrun simctl erase <device>          # so onboarding is shown
//   xcodebuild test -only-testing:GeethaHealthUITests/MarketingScreenshotTests
//   xcrun xcresulttool export attachments --path <result>.xcresult --output-path <dir>
//
// Runs with -uiMockVoice so the voice-entry screen can be captured without
// live speech recognition (unavailable in the Simulator).
//
// All data here is invented. Never use real medical information in marketing assets.
final class MarketingScreenshotTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiMockVoice"]
        app.launch()
    }

    func testCaptureMarketingScreenshots() {
        completeOnboardingIfNeeded()
        seedRecords()

        // 1 — Voice entry, on the confirm card. Runs first because saving it is
        //     what puts a symptom on the board for the Records shot below.
        captureVoiceConfirmCard()

        // 2 — Records home, every category populated. The hero shot.
        goToRecordsRoot()
        waitForUndoSnackbarToClear()
        snap("shot-records")

        // 3 — Profile, showing the on-device storage row and Face ID toggle.
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        // Scroll past the mostly-empty Basics block to the part this shot is
        // actually for: the Face ID toggle and the "On this device only" row.
        app.swipeUp()
        _ = app.staticTexts["On this device only"].waitForExistence(timeout: 3)
        snap("shot-profile")

        // 4 — Ask. Falls back to the deterministic assistant when Foundation
        // Models is unavailable, which still renders the screen we advertise.
        captureAskScreen()
    }

    // MARK: - Flows

    private func completeOnboardingIfNeeded() {
        let firstName = app.textFields["First name"]
        guard firstName.waitForExistence(timeout: 10) else { return }
        firstName.tap()
        firstName.typeText("Geetha")
        let lastName = app.textFields["Last name"]
        lastName.tap()
        lastName.typeText("Gowda")
        app.buttons["Get started"].tap()
        XCTAssertTrue(app.navigationBars["Records"].waitForExistence(timeout: 10),
                      "Did not reach Records after onboarding")
    }

    private func seedRecords() {
        addMedication(name: "Lisinopril", dosage: "10 mg", frequency: "Once daily")
        addMedication(name: "Metformin", dosage: "500 mg", frequency: "Twice daily")
        addSimple(list: "Allergies", field: "Allergy (e.g. Penicillin)", value: "Penicillin",
                  extraField: "Reaction (e.g. hives)", extraValue: "Hives")
        addSimple(list: "Conditions", field: "Condition name", value: "Hypertension")
        addSimple(list: "Immunizations", field: "Vaccine (e.g. Influenza)", value: "Influenza")
        addSimple(list: "Appointments", field: "Title (e.g. Annual physical)", value: "Annual physical",
                  extraField: "Clinician", extraValue: "Dr. Chen")
    }

    private func addMedication(name: String, dosage: String, frequency: String) {
        openList("Medications")
        app.buttons["Add"].tap()

        let field = app.textFields["Medication name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Medication name field missing")
        field.tap()
        field.typeText(name)
        acceptFirstSuggestion(matching: name)

        typeInto("Dosage (e.g. 10 mg)", dosage)
        typeInto("Frequency (e.g. once daily)", frequency)

        app.buttons["Save"].tap()
        back()
    }

    private func addSimple(list: String, field: String, value: String,
                           extraField: String? = nil, extraValue: String? = nil) {
        openList(list)
        app.buttons["Add"].tap()

        let primary = app.textFields[field]
        XCTAssertTrue(primary.waitForExistence(timeout: 5), "\(field) missing")
        primary.tap()
        primary.typeText(value)
        acceptFirstSuggestion(matching: value)

        if let extraField, let extraValue {
            typeInto(extraField, extraValue)
        }

        app.buttons["Save"].tap()
        back()
    }

    private func captureVoiceConfirmCard() {
        goToRecordsRoot()
        app.buttons["Add by voice"].tap()
        dismissConsentSheet()

        let transcript = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "headache")
        ).firstMatch
        guard transcript.waitForExistence(timeout: 10) else {
            XCTFail("Mock transcript never appeared — is -uiMockVoice wired up?")
            return
        }
        app.buttons["Done"].tap()

        // The confirm card is the interesting frame: a spoken sentence resolved
        // into a coded symptom, awaiting the user's approval.
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10),
                      "Voice confirm card never appeared")
        snap("shot-voice")

        // Save it, so Symptoms isn't sitting at zero in the Records shot.
        save.tap()
        _ = app.navigationBars["Records"].waitForExistence(timeout: 5)
    }

    private func captureAskScreen() {
        app.tabBars.buttons["Ask"].tap()
        dismissConsentSheet()

        let field = app.textFields["Ask a question…"]
        if field.waitForExistence(timeout: 5) {
            field.tap()
            // SwiftUI hands focus to the field a beat after the tap, so typing
            // straight into the element races and fails. Wait for the keyboard,
            // then type into the app — which targets whatever actually has focus.
            if app.keyboards.element.waitForExistence(timeout: 5) {
                app.typeText("What medications am I taking?")

                // The field is `axis: .vertical`, so Return inserts a newline
                // instead of submitting — the send button is the only way to
                // actually ask. It also clears focus, dismissing the keyboard,
                // which is what makes the answer visible in the screenshot.
                let send = app.buttons["arrow.up.circle.fill"]
                if send.waitForExistence(timeout: 3) { send.tap() }

                // Let the on-device model (or the deterministic fallback) answer.
                _ = app.staticTexts.containing(
                    NSPredicate(format: "label CONTAINS[c] %@", "Lisinopril")
                ).firstMatch.waitForExistence(timeout: 20)
            }
        }
        // Best-effort: capture whatever state we reached rather than failing the run.
        snap("shot-ask")
    }

    // MARK: - Helpers

    private func openList(_ name: String) {
        goToRecordsRoot()
        app.staticTexts[name].tap()
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5),
                      "Did not open \(name)")
    }

    private func goToRecordsRoot() {
        app.tabBars.buttons["Records"].tap()
        while app.navigationBars.buttons.element(boundBy: 0).exists,
              !app.navigationBars["Records"].exists {
            back()
        }
    }

    /// The voice and Ask features each gate on a first-run consent sheet, and
    /// they use different accept labels ("Continue" vs "I understand"). Try both
    /// rather than hardcoding one and silently screenshotting the consent sheet.
    private func dismissConsentSheet() {
        for label in ["Continue", "I understand"] {
            let button = app.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
        }
    }

    /// Saving by voice raises an "Saved … / Undo" snackbar that clears itself
    /// after 5s. It sits over the bottom of the Records screen, so wait it out
    /// rather than shipping a hero screenshot with transient UI in it.
    private func waitForUndoSnackbarToClear() {
        let snackbar = app.buttons["Undo"]
        guard snackbar.exists else { return }
        expectation(for: NSPredicate(format: "exists == false"),
                    evaluatedWith: snackbar)
        waitForExpectations(timeout: 15)
    }

    private func back() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists { backButton.tap() }
    }

    private func typeInto(_ placeholder: String, _ value: String) {
        let field = app.textFields[placeholder]
        guard field.waitForExistence(timeout: 3) else { return }
        field.tap()
        field.typeText(value)
    }

    /// Medication and vaccine fields autocomplete from the bundled vocabularies.
    /// Tapping the suggestion attaches the RxNorm/CVX code, which is what a real
    /// user's record looks like — worth capturing accurately.
    private func acceptFirstSuggestion(matching name: String) {
        let suggestion = app.buttons.containing(
            NSPredicate(format: "label BEGINSWITH[c] %@", name)
        ).firstMatch
        if suggestion.waitForExistence(timeout: 2) {
            suggestion.tap()
        }
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
