import XCTest

final class ShoppingFlowTests: XCTestCase {
    func testShoppingAndSetup() {
        let app = XCUIApplication()
        app.launchArguments = ["-disableClarity", "-clarityProjectID", ""]
        app.launch()
        XCTAssertTrue(app.buttons["product_1"].waitForExistence(timeout: 10))
        app.buttons["Save Everyday tote"].tap()
        app.buttons["Saved"].tap()
        XCTAssertTrue(app.staticTexts["Everyday tote"].exists)
        XCTAssertFalse(app.staticTexts["Slow morning mug"].exists)
        app.buttons["product_1"].tap()
        app.buttons["Add to bag  ·  $38"].tap()
        app.buttons["Bag (1)"].tap()
        XCTAssertTrue(app.staticTexts["$38"].firstMatch.exists)
        app.buttons["Add one Everyday tote"].tap()
        XCTAssertTrue(app.staticTexts["$76"].exists)
        app.buttons["Remove one Everyday tote"].tap()
        XCTAssertFalse(app.staticTexts["$76"].exists)
        app.buttons["Place demo order"].tap()
        XCTAssertTrue(app.alerts["You're all set"].waitForExistence(timeout: 3))
        app.alerts.buttons["Keep exploring"].tap()
        app.buttons["Bag"].tap()
        XCTAssertTrue(app.staticTexts["A little room for something good."].exists)
        app.buttons["Demo settings"].tap()
        XCTAssertTrue(app.staticTexts["Recording is off"].waitForExistence(timeout: 3))
        app.buttons["Start recording this demo"].tap()
        XCTAssertTrue(app.staticTexts["Paste the project ID, not the dashboard URL."].exists)
        app.buttons["Done"].tap()
        app.buttons["Discover"].tap()
        app.buttons["Tech"].tap()
        XCTAssertTrue(app.staticTexts["Studio headphones"].exists)
        XCTAssertFalse(app.staticTexts["Everyday tote"].exists)
    }
}
