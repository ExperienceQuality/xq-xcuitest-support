# XQ XCUITest Support

Shared XCUITest support for XQ iOS applications. Initial release target:
`0.0.1`.

The package is linked only to consumer UI-test targets. Consumer applications
retain their own bundle identifiers, reset policy, accessibility identifiers,
screen objects, journeys, and device scripts.

Add this package to an app project and link the `XQXCUITestSupport` product only to its UI-test target. The consumer provides one descriptor; the base class owns launch, reset, teardown, and failure diagnostics:

```swift
import XCTest
import XQXCUITestSupport

@MainActor
final class FinanceUITestCase: BaseUITestCase {
    override class var applicationDescriptor: ApplicationDescriptor {
        ApplicationDescriptor(
            bundleIdentifier: "com.xq.finance.ios-xq-finance-app",
            launchConfiguration: LaunchConfiguration(
                arguments: ["--xq-ui-testing"],
                resetArguments: ["--xq-ui-testing-reset"]
            )
        )
    }
}
```

App-owned screen objects and journeys use `application` and `ScreenObject`; an app may override `verifyInitialState(in:)` when needed.

The consumer base class is intentionally minimal. `BaseUITestCase` launches in
`setUp`, applies `resetBeforeEachTest` (true by default), captures screenshot
and accessibility-hierarchy attachments for failures, and terminates in
`tearDown`:

```swift
@MainActor
final class PortfolioTests: FinanceUITestCase {
    func testEmptyPortfolio() {
        application!.staticTexts["portfolio.empty"].requireExistence()
    }
}
```

## API

The package provides `LaunchConfiguration`, `ApplicationDescriptor`,
`BaseUITestCase`, `ScreenObject`, and `XCUIElement` helpers for existence,
hittability, tapping, and text replacement.

## Validation

```sh
swift test
```

The manifest uses Swift tools 5.10, declares iOS 17 and macOS 14 for host-side unit tests, and has no dependencies, plugins, binaries, or resources.

## Consumer validation

Each consumer pins a package revision in `Package.resolved` and links the
product only to its UI-test target. The repository's consumer-validation
workflow documents the required serial `build-for-testing` and
`test-without-building` contract on a pinned iOS 17 simulator. It remains
manual until consumer repositories provide their exact schemes and simulator
destinations.

## License

MIT. See [LICENSE](LICENSE).

## Known limitation

`XCUIApplication`, `XCUIElement`, screenshots, and accessibility hierarchy are XCTest UI-testing APIs. Their availability and link behavior from a Swift package target can differ between command-line SwiftPM and an Xcode iOS UI-test bundle. Consumer POCs must link this product to each UI-test target and run on an iOS 17+ simulator; `swift test` validates only configuration values and host compilation.
