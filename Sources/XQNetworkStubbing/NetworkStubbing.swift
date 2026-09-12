import Foundation

public struct StubResponse: Codable, Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data?

    public init(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        precondition((100...599).contains(statusCode), "statusCode must be between 100 and 599")
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    public static func json<T: Encodable>(
        _ value: T,
        statusCode: Int = 200,
        encoder: JSONEncoder = JSONEncoder()
    ) throws -> StubResponse {
        StubResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "application/json"],
            body: try encoder.encode(value)
        )
    }
}

public struct StubRoute: Codable, Sendable, Equatable {
    public let id: String
    public let method: String
    public let url: URL
    public let response: StubResponse

    public init(
        id: String = UUID().uuidString,
        method: String = "GET",
        url: URL,
        response: StubResponse
    ) {
        precondition(!id.isEmpty && !id.contains("/"), "id must be non-empty and contain no slash")
        self.id = id
        self.method = method.uppercased()
        self.url = url
        self.response = response
    }

    func matches(_ request: URLRequest) -> Bool {
        guard request.httpMethod?.uppercased() == method,
              request.url?.scheme == url.scheme,
              request.url?.host == url.host,
              request.url?.port == url.port,
              request.url?.path == url.path else {
            return false
        }

        return request.url?.query == url.query
    }
}

public final class StubRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var routes: [StubRoute] = []

    public init() {}

    public func replace(with routes: [StubRoute]) {
        lock.withLock { self.routes = routes }
    }

    public func add(_ route: StubRoute) {
        lock.withLock {
            routes.removeAll { $0.id == route.id || ($0.method == route.method && $0.url == route.url) }
            routes.append(route)
        }
    }

    public func remove(_ route: StubRoute) {
        lock.withLock { routes.removeAll { $0 == route } }
    }

    public func reset() {
        lock.withLock { routes.removeAll() }
    }

    public func response(for request: URLRequest) -> StubResponse? {
        lock.withLock { routes.last { $0.matches(request) }?.response }
    }
}

public final class StubURLProtocol: URLProtocol {
    public static let registry = StubRegistry()
    private var stopped = false

    public override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "http" || request.url?.scheme == "https"
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    public override func startLoading() {
        guard !stopped else { return }
        guard let response = Self.registry.response(for: request), let url = request.url else {
            client?.urlProtocol(
                self,
                didFailWithError: StubError.unmatchedRequest(URLRequestDescription(request))
            )
            return
        }

        let httpResponse = HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        if let body = response.body {
            client?.urlProtocol(self, didLoad: body)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    public override func stopLoading() {
        stopped = true
    }
}

public enum XQNetworkStubbing {
    @discardableResult
    public static func install() -> Bool {
        StubURLProtocol.registry.reset()
        return URLProtocol.registerClass(StubURLProtocol.self)
    }

    public static func uninstall() {
        URLProtocol.unregisterClass(StubURLProtocol.self)
        StubURLProtocol.registry.reset()
    }
}

public enum StubError: Error, Equatable, Sendable {
    case unmatchedRequest(URLRequestDescription)
}

public struct URLRequestDescription: Equatable, Sendable {
    public let method: String?
    public let url: String?

    init(_ request: URLRequest) {
        method = request.httpMethod
        url = request.url?.absoluteString
    }
}

private extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
