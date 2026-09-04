import Foundation
import XCTest

@MainActor
private func waitUntilHittable(_ element: XCUIElement, deadline: Date) -> Bool {
    repeat {
        if element.exists, element.isHittable { return true }
        if Date() >= deadline { return false }
        RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.05)))
    } while true
}

@MainActor
private func waitUntilAvailable(_ element: XCUIElement, deadline: Date) -> Bool {
    repeat {
        if element.exists, !element.frame.isEmpty { return true }
        if Date() >= deadline { return false }
        RunLoop.current.run(until: min(deadline, Date().addingTimeInterval(0.05)))
    } while true
}

@MainActor
private func performSwipe(
    on element: XCUIElement,
    direction: SwipeDirection,
    percentage: CGFloat,
    velocity: XCUIGestureVelocity
) throws {
    let vector = try XCUIInteractionPolicy.vector(direction: direction, percentage: percentage)
    let start = element.coordinate(withNormalizedOffset: vector.start)
    let end = element.coordinate(withNormalizedOffset: vector.end)
    start.press(
        forDuration: 0,
        thenDragTo: end,
        withVelocity: velocity,
        thenHoldForDuration: 0
    )
}

@MainActor
public extension XCUIApplication {
    @discardableResult
    func swipe(
        _ direction: SwipeDirection,
        screenPercentage: CGFloat = 0.6,
        velocity: XCUIGestureVelocity = .default,
        timeout: TimeInterval = 8
    ) throws -> Self {
        try XCUIInteractionPolicy.validatePercentage(screenPercentage)
        try XCUIInteractionPolicy.validateTimeout(timeout)

        let deadline = Date().addingTimeInterval(timeout)
        guard waitUntilAvailable(self, deadline: deadline) else {
            throw UIInteractionError.referenceElementUnavailable
        }

        try performSwipe(on: self, direction: direction, percentage: screenPercentage, velocity: velocity)
        return self
    }
}

@MainActor
public extension XCUIElement {
    @discardableResult
    func scrollUntilHittable(
        _ target: XCUIElement,
        direction: SwipeDirection = .up,
        swipePercentage: CGFloat = 0.6,
        maxAttempts: Int = 8,
        velocity: XCUIGestureVelocity = .default,
        timeout: TimeInterval = 8
    ) throws -> Int {
        try XCUIInteractionPolicy.validatePercentage(swipePercentage)
        try XCUIInteractionPolicy.validateMaxAttempts(maxAttempts)
        try XCUIInteractionPolicy.validateTimeout(timeout)

        let deadline = Date().addingTimeInterval(timeout)
        guard waitUntilHittable(self, deadline: deadline), !frame.isEmpty else {
            throw UIInteractionError.referenceElementUnavailable
        }
        return try XCUIInteractionPolicy.runBoundedScroll(
            direction: direction,
            maxAttempts: maxAttempts,
            deadline: deadline.timeIntervalSinceReferenceDate,
            now: { Date.timeIntervalSinceReferenceDate },
            isTargetHittable: { target.exists && target.isHittable },
            performSwipe: {
                try performSwipe(on: self, direction: direction, percentage: swipePercentage, velocity: velocity)
            },
            pollUntil: { pollDeadline in
                waitUntilHittable(target, deadline: Date(timeIntervalSinceReferenceDate: pollDeadline))
            }
        )
    }

    @discardableResult
    func scrollToVisible(
        in container: XCUIElement,
        direction: SwipeDirection = .up,
        swipePercentage: CGFloat = 0.6,
        maxAttempts: Int = 8,
        velocity: XCUIGestureVelocity = .default,
        timeout: TimeInterval = 8
    ) throws -> Self {
        try container.scrollUntilHittable(
            self,
            direction: direction,
            swipePercentage: swipePercentage,
            maxAttempts: maxAttempts,
            velocity: velocity,
            timeout: timeout
        )
        return self
    }

    @discardableResult
    func drag(
        to target: XCUIElement,
        pressDuration: TimeInterval = 0.5,
        velocity: XCUIGestureVelocity = .default,
        holdDuration: TimeInterval = 0.5,
        timeout: TimeInterval = 8
    ) throws -> Self {
        try XCUIInteractionPolicy.validateDuration(pressDuration, name: "pressDuration")
        try XCUIInteractionPolicy.validateDuration(holdDuration, name: "holdDuration")
        try XCUIInteractionPolicy.validateTimeout(timeout)

        let deadline = Date().addingTimeInterval(timeout)
        guard waitUntilHittable(self, deadline: deadline), waitUntilHittable(target, deadline: deadline) else {
            throw UIInteractionError.referenceElementUnavailable
        }

        press(
            forDuration: pressDuration,
            thenDragTo: target,
            withVelocity: velocity,
            thenHoldForDuration: holdDuration
        )
        return self
    }
}
