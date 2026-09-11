import Foundation
import XCTest
@testable import XQNetworkStubbing

final class NetworkStubbingTests: XCTestCase {
    func testRegistryMatchesExactMethodAndURL() throws {
        let registry = StubRegistry()
        let route = StubRoute(
            method: "get",
            url: URL(string: "https://example.com/items?scope=all")!,
            response: StubResponse(statusCode: 201, body: Data("ok".utf8))
        )
        registry.add(route)

        var request = URLRequest(url: route.url)
        request.httpMethod = "GET"
        XCTAssertEqual(registry.response(for: request)?.statusCode, 201)

        request.url = URL(string: "https://example.com/items?scope=other")
        XCTAssertNil(registry.response(for: request))
    }

    func testRegistryResetRemovesRoutes() {
        let registry = StubRegistry()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        registry.add(StubRoute(url: request.url!, response: StubResponse()))

        registry.reset()

        XCTAssertNil(registry.response(for: request))
    }
}
