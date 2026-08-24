import XCTest

public struct LaunchConfiguration: Equatable, Sendable {
    public var arguments: [String]
    public var environment: [String: String]
    public var resetArguments: [String]

    public init(
        arguments: [String] = [],
        environment: [String: String] = [:],
        resetArguments: [String] = []
    ) {
        self.arguments = arguments
        self.environment = environment
        self.resetArguments = resetArguments
    }

    public func arguments(reset: Bool) -> [String] {
        reset ? arguments + resetArguments : arguments
    }
}

public struct ApplicationDescriptor: Equatable, Sendable {
    public let bundleIdentifier: String
    public let launchConfiguration: LaunchConfiguration

    public init(
        bundleIdentifier: String,
        launchConfiguration: LaunchConfiguration = .init()
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.launchConfiguration = launchConfiguration
    }
}

@MainActor
open class BaseUITestCase: XCTestCase {
    open class var applicationDescriptor: ApplicationDescriptor {
        fatalError("Override applicationDescriptor in the consumer UI-test base class")
    }

    open class var resetBeforeEachTest: Bool { true }

    public private(set) var application: XCUIApplication?

    open func verifyInitialState(in application: XCUIApplication) {}

    @discardableResult
    public func launchApplication(_ descriptor: ApplicationDescriptor, reset: Bool) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: descriptor.bundleIdentifier)
        app.launchArguments = descriptor.launchConfiguration.arguments(reset: reset)
        app.launchEnvironment = descriptor.launchConfiguration.environment
        app.launch()
        application = app
        return app
    }

    @discardableResult
    public func launchApplication() -> XCUIApplication {
        launchApplication(Self.applicationDescriptor, reset: Self.resetBeforeEachTest)
    }

    @discardableResult
    public func relaunchApplication(_ descriptor: ApplicationDescriptor, reset: Bool) -> XCUIApplication {
        terminateApplication()
        return launchApplication(descriptor, reset: reset)
    }

    @discardableResult
    public func relaunchApplication() -> XCUIApplication {
        relaunchApplication(Self.applicationDescriptor, reset: Self.resetBeforeEachTest)
    }

    public func terminateApplication() {
        application?.terminate()
        application = nil
    }

    public func attachDiagnostics(named name: String = "failure") {
        guard let application else { return }

        let screenshot = XCTAttachment(screenshot: application.screenshot())
        screenshot.name = "\(name)-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let hierarchy = XCTAttachment(string: application.debugDescription)
        hierarchy.name = "\(name)-accessibility-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }

    override open func setUp() {
        super.setUp()
        continueAfterFailure = false
        let app = launchApplication()
        verifyInitialState(in: app)
    }

    override open func tearDown() {
        if testRun?.failureCount ?? 0 > 0 {
            attachDiagnostics()
        }
        terminateApplication()
        super.tearDown()
    }
}

@MainActor
public protocol ScreenObject {
    var application: XCUIApplication { get }
}

@MainActor
public extension XCUIElement {
    @discardableResult
    func requireExistence(
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        XCTAssertTrue(waitForExistence(timeout: timeout), "Element did not appear", file: file, line: line)
        return self
    }

    func tapWhenHittable(
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExistence(timeout: timeout, file: file, line: line)
        XCTAssertTrue(isHittable, "Element is not hittable", file: file, line: line)
        tap()
    }

    func replaceText(
        with value: String,
        timeout: TimeInterval = 8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        requireExistence(timeout: timeout, file: file, line: line)
        tap()
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 256))
        typeText(value)
    }
}
