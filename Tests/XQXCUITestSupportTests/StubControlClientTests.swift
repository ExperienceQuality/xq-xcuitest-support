import Foundation
import XCTest
@testable import XQNetworkStubbing
@testable import XQXCUITestSupport

final class StubControlClientTests: XCTestCase {
    func testSetSendsAuthenticatedRoute() async throws {
        let recorder = ControlRequestRecorder()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ControlRecorderProtocol.self]
        ControlRecorderProtocol.recorder = recorder
        defer { ControlRecorderProtocol.recorder = nil }

        let client = StubControlClient(
            endpoint: StubControlEndpoint(
                baseURL: URL(string: "http://127.0.0.1:1234")!,
                token: "secret"
            ),
            session: URLSession(configuration: configuration)
        )
        let route = StubRoute(
            id: "portfolio",
            url: URL(string: "https://api.example.com/portfolio")!,
            response: StubResponse(statusCode: 200, body: Data("{}".utf8))
        )

        try await client.set(route)

        XCTAssertEqual(recorder.request?.httpMethod, "PUT")
        XCTAssertEqual(recorder.request?.url?.path, "/__xq_stubs/routes/portfolio")
        XCTAssertEqual(recorder.request?.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(recorder.request?.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }
}

private final class ControlRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequest: URLRequest?
    private var storedBody: Data?

    var request: URLRequest? { lock.withLock { storedRequest } }
    var body: Data? { lock.withLock { storedBody } }

    func record(_ request: URLRequest, body: Data?) {
        lock.withLock {
            storedRequest = request
            storedBody = body
        }
    }
}

private final class ControlRecorderProtocol: URLProtocol {
    static var recorder: ControlRequestRecorder?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.recorder?.record(request, body: request.httpBody)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 204,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
