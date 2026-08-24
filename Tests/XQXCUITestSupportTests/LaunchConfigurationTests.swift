import XCTest
@testable import XQXCUITestSupport

final class LaunchConfigurationTests: XCTestCase {
    func testResetArgumentsAreAppendedOnlyForResetLaunches() {
        let configuration = LaunchConfiguration(
            arguments: ["--ui-testing", "--seed", "42"],
            resetArguments: ["--reset-store"]
        )

        XCTAssertEqual(configuration.arguments(reset: false), ["--ui-testing", "--seed", "42"])
        XCTAssertEqual(
            configuration.arguments(reset: true),
            ["--ui-testing", "--seed", "42", "--reset-store"]
        )
    }

    func testEnvironmentAndDescriptorRemainEquatable() {
        let descriptor = ApplicationDescriptor(
            bundleIdentifier: "com.example.app",
            launchConfiguration: LaunchConfiguration(environment: ["UITEST": "1"])
        )

        XCTAssertEqual(descriptor, descriptor)
        XCTAssertEqual(descriptor.launchConfiguration.environment["UITEST"], "1")
    }
}
