import XCTest

// Drives the voice symptom flow against the mock transcriber + parser
// (`-uiMockVoice`), which replays "I've had a mild headache since Tuesday".
// Verifies the whole pipeline end-to-end in the Simulator: entry point →
// consent → listening → parse/confirm → save → Undo — without live speech or
// Foundation Models.
final class VoiceSymptomUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testVoiceEntryCreatesSymptom() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiMockVoice"]
        app.launch()

        // Entry point on the Records home.
        let addByVoice = app.buttons["Add by voice"]
        XCTAssertTrue(addByVoice.waitForExistence(timeout: 10), "Add by voice entry point missing")
        addByVoice.tap()

        // Consent sheet on first run only.
        let consentContinue = app.buttons["Continue"]
        if consentContinue.waitForExistence(timeout: 3) {
            consentContinue.tap()
        }

        // Listening: the mock transcript streams in. Wait for it to land.
        let transcript = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] %@", "headache")
        ).firstMatch
        XCTAssertTrue(transcript.waitForExistence(timeout: 10), "Mock transcript never appeared")

        app.buttons["Done"].tap()

        // Confirm card resolves the spoken description to a coded symptom.
        let save = app.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 10), "Confirm card / Save button missing")
        XCTAssertTrue(app.staticTexts["Headache"].exists, "Parsed symptom name not shown on confirm card")

        save.tap()

        // Undo snackbar confirms the record was saved.
        XCTAssertTrue(
            app.staticTexts["Saved Headache"].waitForExistence(timeout: 5),
            "Undo snackbar did not confirm the save"
        )

        // And the record is really in the Symptoms list. The row label combines
        // the title with its count, so match on the "Symptoms" text itself.
        app.staticTexts["Symptoms"].tap()
        XCTAssertTrue(
            app.staticTexts["Headache"].waitForExistence(timeout: 5),
            "Saved symptom not found in the Symptoms list"
        )
    }
}
