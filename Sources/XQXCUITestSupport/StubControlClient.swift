import Foundation
import XQNetworkStubbing

public struct StubControlEndpoint: Sendable, Equatable {
    public let baseURL: URL
    public let token: String

    public init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }
}

public enum StubControlError: Error, Equatable, Sendable {
    case invalidEndpoint
    case unauthorized
    case malformedRequest
    case routeNotFound(String)
    case server(statusCode: Int, message: String?)
    case transport(String)
    case timeout
}

public final class StubControlClient: @unchecked Sendable {
    private let endpoint: StubControlEndpoint
    private let session: URLSession
    private let timeout: TimeInterval
    private let encoder = JSONEncoder()

    public init(
        endpoint: StubControlEndpoint,
        session: URLSession = .shared,
        timeout: TimeInterval = 5
    ) {
        self.endpoint = endpoint
        self.session = session
        self.timeout = timeout
    }

    public func health() async throws {
        try await send(path: "__xq_stubs/health", method: "GET")
    }

    public func set(_ route: StubRoute) async throws {
        let body = try encode(route)
        try await send(
            path: "__xq_stubs/routes/\(route.id)",
            method: "PUT",
            body: body
        )
    }

    public func remove(routeID: String) async throws {
        guard !routeID.isEmpty, !routeID.contains("/") else {
            throw StubControlError.malformedRequest
        }
        try await send(path: "__xq_stubs/routes/\(routeID)", method: "DELETE")
    }

    public func reset() async throws {
        try await send(path: "__xq_stubs/reset", method: "POST")
    }

    private func encode(_ route: StubRoute) throws -> Data {
        do {
            return try encoder.encode(route)
        } catch {
            throw StubControlError.malformedRequest
        }
    }

    private func send(path: String, method: String, body: Data? = nil) async throws {
        guard var components = URLComponents(url: endpoint.baseURL, resolvingAgainstBaseURL: false),
              !endpoint.token.isEmpty else {
            throw StubControlError.invalidEndpoint
        }

        if !components.path.hasSuffix("/") { components.path += "/" }
        components.path += path
        guard let url = components.url else { throw StubControlError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.setValue("Bearer \(endpoint.token)", forHTTPHeaderField: "Authorization")
        if body != nil {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw StubControlError.transport("Control server returned non-HTTP response")
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw error(for: httpResponse.statusCode)
            }
        } catch let error as StubControlError {
            throw error
        } catch let error as URLError where error.code == .timedOut {
            throw StubControlError.timeout
        } catch {
            throw StubControlError.transport(error.localizedDescription)
        }
    }

    private func error(for statusCode: Int) -> StubControlError {
        switch statusCode {
        case 400: return .malformedRequest
        case 401, 403: return .unauthorized
        case 404: return .routeNotFound("unknown route")
        default: return .server(statusCode: statusCode, message: nil)
        }
    }
}
