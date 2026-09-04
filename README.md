# XQ XCUITest Support

Shared XCUITest support for XQ iOS applications. Current release:
`0.1.0`.

The package is linked only to consumer UI-test targets. Consumer applications
retain their own bundle identifiers, reset policy, accessibility identifiers,
screen objects, journeys, and device scripts.

## Installation

The consumer is an Xcode project, not another Swift package. This repository's
`Package.swift` is only for building and testing the package; neither consumer
app needs its own `Package.swift`.

### Xcode UI

For a remote package, choose **File > Add Package Dependencies…** in Xcode,
enter this repository URL, and select the required version rule. During local
POC work, choose **File > Add Package Dependencies… > Add Local…** and select
the package checkout instead.

In the package product selection dialog, select `XQXCUITestSupport` for the
existing `FinanceUITests` or `FitnessUITests` target. Confirm under the target's
**General > Frameworks, Libraries, and Embedded Content** (or **Build Phases >
Link Binary With Libraries**) that the product is linked to the UI-test bundle,
not the application target.

### XcodeGen

Declare the package in the consumer's `project.yml`. The path is relative to
the directory containing `project.yml`:

```yaml
packages:
  XQXCUITestSupport:
    path: ../xq-xcuitest-support

targets:
  FinanceUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - FinanceUITests
    dependencies:
      - package: XQXCUITestSupport
        product: XQXCUITestSupport

  FitnessUITests:
    type: bundle.ui-testing
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - FitnessUITests
    dependencies:
      - package: XQXCUITestSupport
        product: XQXCUITestSupport
```

For a release dependency, replace `path` with the repository URL and a
version requirement. Regenerate and resolve the project with:

```sh
xcodegen generate
xcodebuild -resolvePackageDependencies -project YourApp.xcodeproj
```

Commit the generated package resolution file according to the consumer
repository's policy. Xcode normally stores it at
`YourApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
(or under the corresponding `.xcworkspace` directory). `Package.resolved`
pins remote package revisions for reproducible CI builds. A local `path`
dependency is not a registry/version pin; use a tagged remote package before
considering the dependency release-ready.

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

## Interaction API

Directions describe finger motion (for example, `.up` moves the finger upward
and normally reveals content below). Screen and container swipes accept a
finite fraction in `(0, 0.8]`; the default `0.6` keeps each endpoint at least
10% from the referenced element's edges.

```swift
try application.swipe(.left, screenPercentage: 0.6)

let list = application.collectionViews["results"]
let result = application.cells["result.42"]
let attempts = try list.scrollUntilHittable(result, direction: .up, maxAttempts: 8)
try result.scrollToVisible(in: list, direction: .up)

try application.otherElements["card.source"].drag(
    to: application.otherElements["column.destination"]
)
```

`scrollUntilHittable` always acts on the explicitly selected container, checks
the target before the first gesture, and returns the number of gestures used.
It never guesses an ancestor or loops without a bound. `scrollToVisible(in:)`
is the target-returning convenience over that same operation. All interaction
APIs share one timeout budget, reject invalid input with
`UIInteractionError`, and avoid arbitrary sleeps and automatic drag retries.
Keep orientation and layout stable while XCTest injects a gesture. App-specific
overlays can still obscure otherwise valid normalized coordinates.

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

The repository includes `Fixtures/InteractionFixture`, a minimal XcodeGen app
and UI-test target for gesture acceptance. With XcodeGen, full Xcode, and a
pinned iOS 17 simulator installed:

```sh
cd Fixtures/InteractionFixture
xcodegen generate
xcodebuild build-for-testing -project InteractionFixture.xcodeproj \
  -scheme InteractionFixture \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
xcodebuild test-without-building -project InteractionFixture.xcodeproj \
  -scheme InteractionFixture \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.5'
```

Run the UI-test suite serially and repeat it ten times before release. The
fixture covers four swipe directions and percentage boundaries, vertical and
horizontal explicit-container scrolling, already-visible and exhausted target
states, and element-to-element drag/drop. Host-side `swift test` proves only
the deterministic validation and geometry policy, not gesture injection.

## License

MIT. See [LICENSE](LICENSE).

## Known limitation

`XCUIApplication`, `XCUIElement`, screenshots, and accessibility hierarchy are XCTest UI-testing APIs. Their availability and link behavior from a Swift package target can differ between command-line SwiftPM and an Xcode iOS UI-test bundle. Consumer POCs must link this product to each UI-test target and run on an iOS 17+ simulator; `swift test` validates only configuration values and host compilation.
