import XCTest

final class film_spaceUITests: XCTestCase {
    @MainActor func testEditorAndCameraControlsStayReachable() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        XCTAssertTrue(app.buttons["modeEdit"].waitForExistence(timeout: 20))
        for _ in 0..<3 {
            app.buttons["modeCamera"].tap()
            XCTAssertTrue(app.buttons["recordVideo"].waitForExistence(timeout: 5))
            app.buttons["modeEdit"].tap()
        }
        app.buttons["Menu"].tap(); app.buttons["Objects & scene"].tap()
        XCTAssertTrue(app.buttons["Person"].waitForExistence(timeout: 5))
        app.buttons["Person"].tap(); app.buttons["Car"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.sliders["Smooth zoom"].waitForExistence(timeout: 5))
        app.sliders["Smooth zoom"].adjust(toNormalizedSliderPosition: 0.6)
        app.buttons["Zoom out"].tap()
        app.buttons["modeCamera"].tap()
        XCTAssertTrue(app.buttons["Zoom in"].isHittable)
        app.buttons["Hide controls"].tap()
        XCTAssertTrue(app.buttons["Controls"].isHittable)
        app.buttons["Controls"].tap()
        XCTAssertTrue(app.sliders["Smooth zoom"].isHittable)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.buttons["modeEdit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["modeEdit"].isHittable)
        XCTAssertTrue(app.sliders["Smooth zoom"].isHittable)
    }
}
