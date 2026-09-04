import XCTest
import XQXCUITestSupport

@MainActor
final class InteractionFixtureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    override func tearDown() {
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    func testEverySwipeDirectionHasObservableOutcome() throws {
        for direction in SwipeDirection.allCases {
            launch(mode: "swipe")
            try app.swipe(direction, screenPercentage: 0.25)
            XCTAssertEqual(app.staticTexts["gesture.direction"].label, name(of: direction))
            assertRecordedPercentage(25, tolerance: 6)
            app.terminate()
        }
    }

    func testEightyPercentBoundaryInPortraitAndLandscape() throws {
        launch(mode: "swipe")
        try app.swipe(.up, screenPercentage: 0.8)
        XCTAssertEqual(app.staticTexts["gesture.direction"].label, "up")
        assertRecordedPercentage(80, tolerance: 6)
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["gesture.direction"].waitForExistence(timeout: 3))
        try app.swipe(.right, screenPercentage: 0.8)
        XCTAssertEqual(app.staticTexts["gesture.direction"].label, "right")
        assertRecordedPercentage(80, tolerance: 6)
    }

    func testNestedContainersAndKnownAttemptCount() throws {
        launch(mode: "scroll")
        let parent = app.scrollViews["vertical.container"]
        let oneSwipeTarget = app.staticTexts["vertical.one-swipe"]
        XCTAssertEqual(try parent.scrollUntilHittable(oneSwipeTarget, direction: .up, maxAttempts: 2), 1)
        let child = app.scrollViews["horizontal.container"]
        try child.scrollToVisible(in: parent, direction: .up, maxAttempts: 4)
        let horizontalTarget = app.staticTexts["horizontal.target"]
        XCTAssertGreaterThan(try child.scrollUntilHittable(horizontalTarget, direction: .left), 0)
        XCTAssertTrue(horizontalTarget.isHittable)
    }

    func testAlreadyVisibleAndTransientPollingPaths() throws {
        launch(mode: "scroll")
        let parent = app.scrollViews["vertical.container"]
        XCTAssertEqual(try parent.scrollUntilHittable(app.staticTexts["vertical.visible"]), 0)
        let attempts = try parent.scrollUntilHittable(
            app.staticTexts["vertical.transient"],
            direction: .down,
            maxAttempts: 2,
            timeout: 2
        )
        XCTAssertGreaterThanOrEqual(attempts, 1)
        XCTAssertLessThanOrEqual(attempts, 2)
        XCTAssertTrue(app.staticTexts["vertical.transient"].isHittable)
    }

    func testInvalidArgumentsFailBeforeGestureAndCoveredReferencesFailClearly() throws {
        launch(mode: "swipe")
        XCTAssertThrowsError(try app.swipe(.up, screenPercentage: 0))
        XCTAssertThrowsError(try app.swipe(.up, screenPercentage: 0.81))
        XCTAssertThrowsError(try app.swipe(.up, timeout: 0))
        XCTAssertEqual(app.staticTexts["gesture.direction"].label, "none")
        app.terminate()
        launch(mode: "covered")
        XCTAssertThrowsError(try app.scrollViews["covered.container"].scrollUntilHittable(
            app.staticTexts["covered.target"],
            maxAttempts: 1,
            timeout: 0.5
        ))
    }

    func testOffscreenDragSourceFailsWithoutRetry() throws {
        launch(mode: "scroll")
        XCTAssertThrowsError(try app.staticTexts["offscreen.source"].drag(
            to: app.staticTexts["vertical.visible"],
            timeout: 0.5
        ))
    }

    func testHittableDragUpdatesObservableDropState() throws {
        launch(mode: "scroll")
        let container = app.scrollViews["vertical.container"]
        let dragSource = app.staticTexts["drag.source"]
        let dragTarget = app.staticTexts["drag.target"]
        let dropResult = app.staticTexts["drop.result"]

        try dragSource.scrollToVisible(in: container, direction: .up, maxAttempts: 4)
        XCTAssertTrue(dragTarget.waitForExistence(timeout: 2))
        XCTAssertTrue(dragTarget.isHittable)
        XCTAssertEqual(dropResult.label, "drop-count-0")

        try dragSource.drag(to: dragTarget)

        let mutation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "drop-count-1"),
            object: dropResult
        )
        XCTAssertEqual(XCTWaiter.wait(for: [mutation], timeout: 2), .completed)
        XCTAssertEqual(dropResult.label, "drop-count-1")
    }

    private func launch(mode: String) {
        app = XCUIApplication()
        app.launchArguments = ["--fixture", mode]
        app.launch()
    }

    private func assertRecordedPercentage(_ expected: Int, tolerance: Int) {
        let label = app.staticTexts["gesture.percentage"].label
        guard let actual = Int(label) else { return XCTFail("Invalid recorded percentage: \(label)") }
        XCTAssertEqual(actual, expected, accuracy: tolerance)
    }

    private func name(of direction: SwipeDirection) -> String {
        switch direction {
        case .up: "up"
        case .down: "down"
        case .left: "left"
        case .right: "right"
        }
    }
}
