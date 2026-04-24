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

    func testSelectMotionArtworkPrefersSongRelationshipAlbumOrder() {
        let relationshipURL = URL(string: "https://example.com/relationship.m3u8")!
        let fallbackURL = URL(string: "https://example.com/fallback.m3u8")!
        let response = Self.makeCatalogResponse(
            songID: "42",
            relationshipAlbumID: "album-relationship",
            relationshipURL: relationshipURL,
            fallbackAlbumID: "album-fallback",
            fallbackURL: fallbackURL
        )

        let selection = iTunesKit.selectMotionArtwork(in: response, preferredSongID: "42")

        XCTAssertEqual(selection?.albumID, "album-relationship")
        XCTAssertEqual(selection?.sourceURL, relationshipURL)
    }

    func testResolveMotionArtworkReturnsCollectionAndAlbumMetadata() async throws {
        let token = makeFakeToken()
        let cacheURL = Self.makeTemporaryCacheURL(name: "resolve-motion-token-cache.json")

        let relationshipURL = URL(string: "https://example.com/relationship.m3u8")!
        let fallbackURL = URL(string: "https://example.com/fallback.m3u8")!
        let catalogResponse = Self.makeCatalogResponse(
            songID: "42",
            relationshipAlbumID: "album-relationship",
            relationshipURL: relationshipURL,
            fallbackAlbumID: "album-fallback",
            fallbackURL: fallbackURL
        )
        let catalogData = try JSONEncoder().encode(catalogResponse)

        let session = Self.makeSession { request in
            guard let url = request.url?.absoluteString else {
                return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 400)
            }

            if url.contains("itunes.apple.com/search") {
                let json = """
                {
                  "resultCount": 1,
                  "results": [
                    {
                      "trackId": 42,
                      "collectionId": 9001,
                      "trackName": "Test Song",
                      "artistName": "Test Artist"
                    }
                  ]
                }
                """

                return Self.makeStubResponse(url: request.url, body: Data(json.utf8))
            }

            if url == Secrets.webNewURL {
                let html = "<html><head><script src=\"/assets/index~test.js\"></script></head><body></body></html>"
                return Self.makeStubResponse(url: request.url, body: Data(html.utf8))
            }

            if url == "https://music.apple.com/assets/index~test.js" {
                let script = "const devToken = \"\(token)\";"
                return Self.makeStubResponse(url: request.url, body: Data(script.utf8))
            }

            if url.contains("amp-api.music.apple.com/v1/catalog/us/songs/42") {
                return Self.makeStubResponse(url: request.url, body: catalogData)
            }

            return Self.makeStubResponse(url: request.url, body: Data(), statusCode: 404)
        }

        let searchService = SearchService(session: session)
        let tokenService = iTunesWebTokenService(session: session, cacheURL: cacheURL)
        let webClient = iTunesWebServiceClient(tokenService: tokenService, session: session)
        let webCatalogService = WebCatalogService(client: webClient)
        let kit = iTunesKit(
            searchService: searchService,
            makeWebCatalogService: { webCatalogService }
        )

        let resolution = try await kit.resolveMotionArtwork(term: "test song test artist")

        XCTAssertEqual(resolution?.trackID, 42)
        XCTAssertEqual(resolution?.collectionID, 9001)
        XCTAssertEqual(resolution?.catalogAlbumID, "album-relationship")
        XCTAssertEqual(resolution?.sourceURL, relationshipURL)
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

    private static func makeCatalogResponse(
        songID: String,
        relationshipAlbumID: String,
        relationshipURL: URL,
        fallbackAlbumID: String,
        fallbackURL: URL
    ) -> iTunesCatalogResponse {
        let relationshipAlbum = Album(
            id: relationshipAlbumID,
            type: "albums",
            href: "/v1/catalog/us/albums/\(relationshipAlbumID)",
            attributes: AlbumAttributes(
                editorialVideo: makeEditorialVideo(url: relationshipURL.absoluteString)
            )
        )

        let fallbackAlbum = Album(
            id: fallbackAlbumID,
            type: "albums",
            href: "/v1/catalog/us/albums/\(fallbackAlbumID)",
            attributes: AlbumAttributes(
                editorialVideo: makeEditorialVideo(url: fallbackURL.absoluteString)
            )
        )

        let song = Song(
            id: songID,
            type: "songs",
            href: "/v1/catalog/us/songs/\(songID)",
            attributes: SongAttributes(
                hasLyrics: true,
                name: "Test Song",
                url: "https://music.apple.com/us/song/test-song/\(songID)"
            ),
            relationships: SongRelationships(
                albums: RelationshipAlbums(
                    href: "/v1/catalog/us/songs/\(songID)/albums",
                    data: [
                        iTunesCatalogData(
                            id: relationshipAlbumID,
                            type: "albums",
                            href: "/v1/catalog/us/albums/\(relationshipAlbumID)"
                        )
                    ]
                )
            )
        )

        return iTunesCatalogResponse(
            data: [
                iTunesCatalogData(
                    id: songID,
                    type: "songs",
                    href: "/v1/catalog/us/songs/\(songID)"
                )
            ],
            resources: Resources(
                albums: [
                    fallbackAlbumID: fallbackAlbum,
                    relationshipAlbumID: relationshipAlbum
                ],
                songs: [
                    songID: song
                ]
            )
        )
    }

    private static func makeEditorialVideo(url: String) -> EditorialVideo {
        let motion = makeMotionVideo(url: url)
        return EditorialVideo(
            motionDetailSquare: motion,
            motionDetailTall: motion,
            motionSquareVideo1X1: motion,
            motionTallVideo3X4: motion
        )
    }

    private static func makeMotionVideo(url: String) -> MotionVideo {
        MotionVideo(
            previewFrame: PreviewFrame(
                bgColor: "000000",
                hasP3: false,
                height: 100,
                textColor1: "FFFFFF",
                textColor2: "FFFFFF",
                textColor3: "FFFFFF",
                textColor4: "FFFFFF",
                url: "https://example.com/preview.jpg",
                width: 100
            ),
            video: url
        )
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
