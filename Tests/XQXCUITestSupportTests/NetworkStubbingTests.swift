import Foundation
import XCTest
@testable import XQNetworkStubbing

final class NetworkStubbingTests: XCTestCase {
    func testRegistryMatchesExactMethodAndURL() throws {
        let registry = StubRegistry()
        let route = StubRoute(
            id: "items",
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

    func testRouteAndResponseAreCodable() throws {
        let route = StubRoute(
            id: "portfolio",
            method: "GET",
            url: URL(string: "https://example.com/portfolio")!,
            response: StubResponse(
                statusCode: 503,
                headers: ["Retry-After": "1"],
                body: Data("busy".utf8)
            )
        )

        let data = try JSONEncoder().encode(route)

        XCTAssertEqual(try JSONDecoder().decode(StubRoute.self, from: data), route)
    }
}
