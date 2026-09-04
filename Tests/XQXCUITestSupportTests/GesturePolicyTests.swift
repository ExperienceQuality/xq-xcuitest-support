import CoreGraphics
import XCTest
@testable import XQXCUITestSupport

final class GesturePolicyTests: XCTestCase {
    func testAllDirectionsProduceSymmetricVectors() throws {
        let expected: [SwipeDirection: GestureVector] = [
            .up: .init(start: .init(dx: 0.5, dy: 0.8), end: .init(dx: 0.5, dy: 0.2)),
            .down: .init(start: .init(dx: 0.5, dy: 0.2), end: .init(dx: 0.5, dy: 0.8)),
            .left: .init(start: .init(dx: 0.8, dy: 0.5), end: .init(dx: 0.2, dy: 0.5)),
            .right: .init(start: .init(dx: 0.2, dy: 0.5), end: .init(dx: 0.8, dy: 0.5))
        ]

        XCTAssertEqual(SwipeDirection.allCases.count, 4)
        for direction in SwipeDirection.allCases {
            XCTAssertEqual(try XCUIInteractionPolicy.vector(direction: direction, percentage: 0.6), expected[direction])
        }
    }

    func testMaximumPercentagePreservesTenPercentMargins() throws {
        for direction in SwipeDirection.allCases {
            let vector = try XCUIInteractionPolicy.vector(direction: direction, percentage: 0.8)
            for component in [vector.start.dx, vector.start.dy, vector.end.dx, vector.end.dy] {
                XCTAssertGreaterThanOrEqual(component, 0.1 - 0.000_001)
                XCTAssertLessThanOrEqual(component, 0.9 + 0.000_001)
            }
        }
    }

    func testSmallPositivePercentageIsAccepted() {
        XCTAssertNoThrow(try XCUIInteractionPolicy.validatePercentage(.leastNonzeroMagnitude))
    }

    func testInvalidPercentagesAreRejected() {
        for percentage: CGFloat in [0, -0.1, 0.81, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try XCUIInteractionPolicy.validatePercentage(percentage)) {
                guard case UIInteractionError.invalidScreenPercentage(let actual) = $0 else {
                    return XCTFail("Unexpected error: \($0)")
                }
                if percentage.isNaN { XCTAssertTrue(actual.isNaN) } else { XCTAssertEqual(actual, percentage) }
            }
        }
    }

    func testAttemptValidation() {
        XCTAssertNoThrow(try XCUIInteractionPolicy.validateMaxAttempts(1))
        XCTAssertThrowsError(try XCUIInteractionPolicy.validateMaxAttempts(0))
        XCTAssertThrowsError(try XCUIInteractionPolicy.validateMaxAttempts(-1))
    }

    func testTimeoutValidation() {
        XCTAssertNoThrow(try XCUIInteractionPolicy.validateTimeout(0.001))
        XCTAssertNoThrow(try XCUIInteractionPolicy.validateTimeout(8))
        for timeout in [0, -0.1, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try XCUIInteractionPolicy.validateTimeout(timeout))
        }
    }

    func testDurationValidation() {
        XCTAssertNoThrow(try XCUIInteractionPolicy.validateDuration(0, name: "duration"))
        XCTAssertNoThrow(try XCUIInteractionPolicy.validateDuration(0.5, name: "duration"))
        for duration in [-0.1, .infinity, -.infinity, .nan] {
            XCTAssertThrowsError(try XCUIInteractionPolicy.validateDuration(duration, name: "duration"))
        }
    }

    func testBoundedScrollReturnsZeroWithoutGestureWhenAlreadyVisible() throws {
        var gestures = 0
        let attempts = try XCUIInteractionPolicy.runBoundedScroll(
            direction: .up,
            maxAttempts: 8,
            deadline: 10,
            now: { 0 },
            isTargetHittable: { true },
            performSwipe: { gestures += 1 },
            pollUntil: { _ in XCTFail("Polling is unnecessary"); return false }
        )
        XCTAssertEqual(attempts, 0)
        XCTAssertEqual(gestures, 0)
    }

    func testBoundedScrollReturnsExactSuccessfulAttempt() throws {
        var gestures = 0
        let attempts = try XCUIInteractionPolicy.runBoundedScroll(
            direction: .left,
            maxAttempts: 8,
            deadline: 10,
            now: { 0 },
            isTargetHittable: { gestures == 3 },
            performSwipe: { gestures += 1 },
            pollUntil: { _ in false }
        )
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(gestures, 3)
    }

    func testBoundedScrollExhaustsExactAttemptLimit() {
        var gestures = 0
        XCTAssertThrowsError(try XCUIInteractionPolicy.runBoundedScroll(
            direction: .down,
            maxAttempts: 4,
            deadline: 10,
            now: { 0 },
            isTargetHittable: { false },
            performSwipe: { gestures += 1 },
            pollUntil: { _ in false }
        )) {
            XCTAssertEqual($0 as? UIInteractionError, .targetNotHittable(direction: .down, attempts: 4))
        }
        XCTAssertEqual(gestures, 4)
    }

    func testBoundedScrollUsesOneAbsoluteDeadlineAcrossAttempts() {
        var clock: TimeInterval = 2
        var pollDeadlines: [TimeInterval] = []
        XCTAssertThrowsError(try XCUIInteractionPolicy.runBoundedScroll(
            direction: .right,
            maxAttempts: 8,
            deadline: 2.6,
            observationInterval: 0.25,
            now: { clock },
            isTargetHittable: { false },
            performSwipe: { clock += 0.2 },
            pollUntil: { deadline in
                pollDeadlines.append(deadline)
                clock = deadline
                return false
            }
        )) {
            XCTAssertEqual($0 as? UIInteractionError, .targetNotHittable(direction: .right, attempts: 2))
        }
        XCTAssertEqual(pollDeadlines, [2.45])
        XCTAssertEqual(clock, 2.65, accuracy: 0.000_001)
        XCTAssertTrue(pollDeadlines.allSatisfy { $0 <= 2.6 })
    }

    func testBoundedScrollAcceptsTransientPollingSuccess() throws {
        var gestures = 0
        var polls = 0
        let attempts = try XCUIInteractionPolicy.runBoundedScroll(
            direction: .up,
            maxAttempts: 3,
            deadline: 1,
            now: { 0 },
            isTargetHittable: { false },
            performSwipe: { gestures += 1 },
            pollUntil: { deadline in
                XCTAssertLessThanOrEqual(deadline, 1)
                polls += 1
                return true
            }
        )
        XCTAssertEqual(attempts, 1)
        XCTAssertEqual(gestures, 1)
        XCTAssertEqual(polls, 1)
    }
}
