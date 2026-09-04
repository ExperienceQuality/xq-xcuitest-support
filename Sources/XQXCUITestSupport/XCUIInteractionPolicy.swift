import CoreGraphics
import Foundation

public enum SwipeDirection: Sendable, CaseIterable {
    case up
    case down
    case left
    case right
}

public enum UIInteractionError: Error, Equatable, Sendable {
    case invalidScreenPercentage(CGFloat)
    case invalidMaxAttempts(Int)
    case invalidTimeout(TimeInterval)
    case invalidDuration(name: String, value: TimeInterval)
    case referenceElementUnavailable
    case targetNotHittable(direction: SwipeDirection, attempts: Int)
}

struct GestureVector: Equatable {
    let start: CGVector
    let end: CGVector
}

enum XCUIInteractionPolicy {
    static let maximumPercentage: CGFloat = 0.8
    static let edgeMargin: CGFloat = 0.1

    static func validatePercentage(_ percentage: CGFloat) throws {
        guard percentage.isFinite, percentage > 0, percentage <= maximumPercentage else {
            throw UIInteractionError.invalidScreenPercentage(percentage)
        }
    }

    static func validateTimeout(_ timeout: TimeInterval) throws {
        guard timeout.isFinite, timeout > 0 else {
            throw UIInteractionError.invalidTimeout(timeout)
        }
    }

    static func validateMaxAttempts(_ attempts: Int) throws {
        guard attempts > 0 else {
            throw UIInteractionError.invalidMaxAttempts(attempts)
        }
    }

    static func validateDuration(_ duration: TimeInterval, name: String) throws {
        guard duration.isFinite, duration >= 0 else {
            throw UIInteractionError.invalidDuration(name: name, value: duration)
        }
    }

    static func vector(direction: SwipeDirection, percentage: CGFloat) throws -> GestureVector {
        try validatePercentage(percentage)

        let half = percentage / 2
        let low = 0.5 - half
        let high = 0.5 + half

        switch direction {
        case .up:
            return GestureVector(start: CGVector(dx: 0.5, dy: high), end: CGVector(dx: 0.5, dy: low))
        case .down:
            return GestureVector(start: CGVector(dx: 0.5, dy: low), end: CGVector(dx: 0.5, dy: high))
        case .left:
            return GestureVector(start: CGVector(dx: high, dy: 0.5), end: CGVector(dx: low, dy: 0.5))
        case .right:
            return GestureVector(start: CGVector(dx: low, dy: 0.5), end: CGVector(dx: high, dy: 0.5))
        }
    }

    static func runBoundedScroll(
        direction: SwipeDirection,
        maxAttempts: Int,
        deadline: TimeInterval,
        observationInterval: TimeInterval = 0.25,
        now: () -> TimeInterval,
        isTargetHittable: () -> Bool,
        performSwipe: () throws -> Void,
        pollUntil: (TimeInterval) -> Bool
    ) throws -> Int {
        if isTargetHittable() { return 0 }

        var attempts = 0
        while attempts < maxAttempts, now() < deadline {
            try performSwipe()
            attempts += 1
            if isTargetHittable() { return attempts }

            let pollDeadline = min(deadline, now() + observationInterval)
            if now() < pollDeadline, pollUntil(pollDeadline) { return attempts }
        }

        throw UIInteractionError.targetNotHittable(direction: direction, attempts: attempts)
    }
}
