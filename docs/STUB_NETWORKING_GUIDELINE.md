# Network stubbing guideline

## Purpose

`XQNetworkStubbing` provides deterministic HTTP response stubbing for consumer
apps during UI tests. It is test infrastructure, not an application networking
abstraction.

The stub runtime runs inside the app process. The XCUITest runner controls it
through a separate control channel in a later integration slice. Registering a
`URLProtocol` only in the UI-test bundle cannot intercept requests made by the
app process.

## Package boundaries

Keep two products separate:

- `XQXCUITestSupport`: XCTest types, app launch, UI interactions, diagnostics,
  and the eventual control client.
- `XQNetworkStubbing`: Foundation-only route models, registry, and
  `URLProtocol` implementation.

`XQNetworkStubbing` must not import XCTest or depend on a consumer app.

## App opt-in

Consumers opt in only for debug/UI-testing launches:

```swift
#if DEBUG
if ProcessInfo.processInfo.arguments.contains("--xq-ui-testing") {
    try? XQNetworkStubbing.install()
}
#endif
```

Release builds must not install the stub runtime. Stubbing must be disabled by
default, and normal launches must retain normal networking behavior.

## Route contract

First implementation matches:

- HTTP method, case-insensitive;
- URL scheme;
- host;
- port;
- path;
- complete query string.

Matching must be deterministic. The latest route for an identical method and
URL replaces the previous route. Unmatched requests fail immediately while
stubbing is enabled; they must not silently reach a real backend.

## Response contract

Responses may define:

- status code from `100` through `599`;
- response headers;
- optional body data;
- JSON convenience encoding.

Later slices may add delay, transport errors, and response sequences. Keep
these features behind the same route interface rather than adding test-specific
branches to consumer networking code.

## Runtime control

Launch arguments and environment variables select the stub-enabled mode and
bootstrap control-server configuration. They do not update an already-running
app.

Runtime route changes use a localhost control channel:

```text
UI test -> control client -> app-local stub server -> StubRegistry
App URLSession -> StubURLProtocol -> StubRegistry
```

The control server must:

- bind to loopback only;
- use a random port;
- require a per-launch random token;
- expose route replacement, removal, reset, and health operations;
- reject malformed or unauthorized requests;
- stop when the app terminates.

## Isolation and safety

- Reset registry at install and test teardown.
- Use unique port/token state for every app launch.
- Never share mutable registry state across test processes.
- Avoid arbitrary sleeps; control calls return only after registry mutation is
  complete.
- Preserve request cancellation behavior where supported by `URLProtocol`.
- Do not support background `URLSession` through this mechanism; Apple does not
  support custom protocol classes for background sessions.

## Non-goals

This package does not intercept:

- `Network.framework` traffic;
- raw sockets;
- networking stacks that bypass `URLSession`;
- background-session requests;
- real-device traffic through an external proxy.

Consumer integration must verify that the app networking path uses a supported
`URLSession` configuration.

## Delivery order

1. Core route/response models and thread-safe registry.
2. `StubURLProtocol` and unmatched-request failure.
3. App-local control server.
4. UI-test control client.
5. Consumer fixture proving runtime response replacement.
6. Sequential responses, delays, and transport errors.

Do not add consumer repositories to the support-package change until the core
contract and control protocol are stable.
