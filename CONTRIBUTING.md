# Contributing

Open a pull request against `main`. Keep the package dependency-free and limit
the public API to reusable XCUITest lifecycle, launch, diagnostics, and
element-synchronization support. Consumer-specific screens and journeys belong
in the consuming app.

All pull requests must pass the package CI workflow and receive review from a
repository code owner. Releases use immutable semantic-version tags and are
approved through the protected `release` environment.
