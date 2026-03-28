import Foundation
import XCTest
@testable import iTunesKit

final class iTunesKitTests: XCTestCase {
    func testSearchServiceDecodesSearchResponse() async throws {
        let session = Self.makeSession { request in
            guard request.url?.absoluteString.contains("itunes.apple.com/search") == true else {
                return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 404)
            }

            let json = """
            {
              "resultCount": 1,
              "results": [
                {
                  "trackId": 42,
                  "trackName": "Test Song",
                  "artistName": "Test Artist"
                }
              ]
            }
            """

            return Self.makeStubResponse(url: request.url, body: Data(json.utf8))
        }

        let service = SearchService(session: session)
        let response = try await service.search(term: "test song", media: "music", limit: 1)

        XCTAssertEqual(response.resultCount, 1)
        XCTAssertEqual(response.results.first?.trackId, 42)
        XCTAssertEqual(response.results.first?.trackName, "Test Song")
    }

    func testWebClientUsesPersistedTokenWithoutRescraping() async throws {
        let token = makeFakeToken()
        let cacheURL = Self.makeTemporaryCacheURL(name: "web-token-cache.json")
        let requests = RequestTracker()

        let session = Self.makeSession { request in
            requests.increment()

            guard let url = request.url?.absoluteString else {
                return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 400)
            }

            if url == Secrets.webNewURL {
                let html = "<html><head><script src=\"/assets/index~test.js\"></script></head><body></body></html>"
                return Self.makeStubResponse(url: request.url, body: Data(html.utf8))
            }

            if url == "https://music.apple.com/assets/index~test.js" {
                let script = "const devToken = \"\(token)\";"
                return Self.makeStubResponse(url: request.url, body: Data(script.utf8))
            }

            if url.contains("amp-api.music.apple.com") {
                let authorization = request.value(forHTTPHeaderField: "Authorization")
                XCTAssertEqual(authorization, "Bearer \(token)")

                let json = """
                { "message": "ok" }
                """
                return Self.makeStubResponse(url: request.url, body: Data(json.utf8))
            }

            return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 404)
        }

        struct EchoResponse: Codable, Equatable {
            let message: String
        }

        let firstClient = iTunesWebServiceClient(
            tokenService: iTunesWebTokenService(session: session, cacheURL: cacheURL),
            session: session
        )

        let firstResponse: EchoResponse = try await firstClient.send("test")
        XCTAssertEqual(firstResponse, EchoResponse(message: "ok"))
        let firstRequestCount = requests.currentValue()
        XCTAssertEqual(firstRequestCount, 3)

        let secondClient = iTunesWebServiceClient(
            tokenService: iTunesWebTokenService(session: session, cacheURL: cacheURL),
            session: session
        )

        let secondResponse: EchoResponse = try await secondClient.send("test")
        XCTAssertEqual(secondResponse, EchoResponse(message: "ok"))
        let secondRequestCount = requests.currentValue()
        XCTAssertEqual(secondRequestCount, 4)
    }

    func testTokenServiceCachesAcrossInstances() async throws {
        let token = makeFakeToken()
        let cacheURL = Self.makeTemporaryCacheURL(name: "token-cache.json")
        let requests = RequestTracker()

        let session = Self.makeSession { request in
            requests.increment()

            guard let url = request.url?.absoluteString else {
                return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 400)
            }

            if url == Secrets.webNewURL {
                let html = "<html><head><script src=\"/assets/index~test.js\"></script></head><body></body></html>"
                return Self.makeStubResponse(url: request.url, body: Data(html.utf8))
            }

            if url == "https://music.apple.com/assets/index~test.js" {
                let script = "const devToken = \"\(token)\";"
                return Self.makeStubResponse(url: request.url, body: Data(script.utf8))
            }

            return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 404)
        }

        let firstService = iTunesWebTokenService(session: session, cacheURL: cacheURL)
        let firstToken = try await firstService.fetchToken()

        XCTAssertEqual(firstToken, token)
        let firstRequestCount = requests.currentValue()
        XCTAssertEqual(firstRequestCount, 2)

        let secondService = iTunesWebTokenService(session: session, cacheURL: cacheURL)
        let secondToken = try await secondService.fetchToken()

        XCTAssertEqual(secondToken, token)
        let secondRequestCount = requests.currentValue()
        XCTAssertEqual(secondRequestCount, 2)
    }

    private static func makeSession(handler: @escaping @Sendable (URLRequest) -> StubbedResponse) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        StubURLProtocol.requestHandler = handler
        return URLSession(configuration: configuration)
    }

    private static func makeStubResponse(url: URL?, body: Data, statusCode: Int = 200) -> StubbedResponse {
        let response = HTTPURLResponse(
            url: url ?? URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!

        return StubbedResponse(response: response, body: body)
    }

    private func makeFakeToken() -> String {
        "eyJ" + String(repeating: "a", count: 210) + ".bbb.ccc"
    }

    private static func makeTemporaryCacheURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private struct StubbedResponse {
        let response: HTTPURLResponse
        let body: Data
    }

    private final class RequestTracker: @unchecked Sendable {
        private let lock = NSLock()
        private var count = 0

        func increment() {
            lock.lock()
            defer { lock.unlock() }
            count += 1
        }

        func currentValue() -> Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }

    private final class StubURLProtocol: URLProtocol {
        nonisolated(unsafe) static var requestHandler: (@Sendable (URLRequest) -> StubbedResponse)?

        override class func canInit(with request: URLRequest) -> Bool {
            true
        }

        override class func canonicalRequest(for request: URLRequest) -> URLRequest {
            request
        }

        override func startLoading() {
            guard let handler = Self.requestHandler else {
                client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
                return
            }

            let stubbedResponse = handler(request)
            client?.urlProtocol(self, didReceive: stubbedResponse.response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: stubbedResponse.body)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }
}
