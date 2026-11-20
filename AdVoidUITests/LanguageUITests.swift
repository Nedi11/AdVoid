import XCTest

final class LanguageUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch(_ language: String, tab: String = "home", largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-skipPaywall", "-hasSeenOnboarding", "YES", "-demoProtected", "-demoStats",
                               "-demoTab", tab, "-demoLanguage", language]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        return app
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testWritingSystemsAndRegionalVariants() {
        for language in ["ar", "ur", "zh-Hans", "zh-Hant", "ja", "ko", "th", "hi", "bn", "gu", "kn", "ml", "mr", "or", "pa", "ta", "te", "de", "fi", "en-GB", "fr-CA", "es-MX", "pt-BR", "pt-PT"] {
            let app = launch(language)
            capture(app, name: "\(language)-home")
            // Physical tab order may be reversed in RTL. Each index still visits a real screen.
            for index in 0..<4 {
                app.tabBars.buttons.element(boundBy: index).tap()
                XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
                capture(app, name: "\(language)-tab-\(index)")
            }
            app.terminate()
        }
    }

    func testLargeAccessibilityText() {
        for language in ["ar", "fi", "hi"] {
            let app = launch(language, largeText: true)
            capture(app, name: "\(language)-accessibility-home")
            app.tabBars.buttons.element(boundBy: 3).tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
            capture(app, name: "\(language)-accessibility-settings")
            app.terminate()
        }
    }

    private func chooseLanguage(_ code: String, in app: XCUIApplication) {
        let row = app.descendants(matching: .any)["language-option-\(code)"]
        for _ in 0..<20 {
            if row.exists && row.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(row.exists)
        row.tap()
    }

    func testRuntimeSwitchKeepsSettingsAndChangesDirection() {
        let app = launch("en", tab: "settings")
        let picker = app.buttons["languagePicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        chooseLanguage("ar", in: app)
        XCTAssertTrue(app.buttons["languagePicker"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.tabBars.buttons.element(boundBy: 0).frame.midX,
                             app.tabBars.buttons.element(boundBy: 3).frame.midX)
        capture(app, name: "runtime-arabic-settings")
        // Relaunch without a language seed: the real saved choice must survive.
        app.terminate()
        app.launchArguments.removeLast(2)
        app.launch()
        XCTAssertTrue(app.buttons["languagePicker"].waitForExistence(timeout: 10))
        XCTAssertGreaterThan(app.tabBars.buttons.element(boundBy: 0).frame.midX,
                             app.tabBars.buttons.element(boundBy: 3).frame.midX)
        app.buttons["languagePicker"].tap()
        chooseLanguage("en", in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        XCTAssertLessThan(app.tabBars.buttons.element(boundBy: 0).frame.midX,
                          app.tabBars.buttons.element(boundBy: 3).frame.midX)
        capture(app, name: "runtime-english-settings")
    }
}
