import XCTest
@testable import iTunesKit

final class iTunesKitTests: XCTestCase {
    func testCatalogDecodingAndBestMotionArt() throws {
        let response = try decodeSampleCatalogResponse()

        XCTAssertEqual(response.data?.first?.identifier, "1699712644")
        XCTAssertEqual(response.resources?.songs?["1699712644"]?.attributes?.title, "MY EYES")
        XCTAssertEqual(response.resources?.albums?["1699712635"]?.attributes?.title, nil)

        let mediaService = MediaService()
        let bestMotionArt = mediaService.bestMotionArt(in: response, songID: "1699712644")

        XCTAssertEqual(bestMotionArt?.videoURL, "https://mvod.itunes.apple.com/itunes-assets/HLSMusic126/v4/e2/a2/96/e2a296a2-f0b7-e951-b543-c0795f99d661/P606897945_default.m3u8")
        XCTAssertEqual(mediaService.bestVideoURL(in: response, songID: "1699712644")?.absoluteString, bestMotionArt?.videoURL)

        // Write outputs for manual inspection
        let catalogOut = """
        Catalog bestVideoURL: \(mediaService.bestVideoURL(in: response, songID: "1699712644")?.absoluteString ?? "nil")
        BestMotionArt videoURL: \(bestMotionArt?.videoURL ?? "nil")

        """
        try? Self.appendTestOutput(catalogOut)
    }

    func testWebPlayerHeadersIncludeBearerToken() {
        let headers = WebPlayerHeaders.headers(authorization: "abc123")

        XCTAssertEqual(headers["Authorization"], "Bearer abc123")
        XCTAssertEqual(headers["Origin"], "https://music.apple.com")
        XCTAssertEqual(headers["User-Agent"], Secrets.userAgent)

        let headersOut = """
        Headers:
        \(headers.map { "\($0): \($1)" }.joined(separator: "\n"))

        """
        try? Self.appendTestOutput(headersOut)
    }

    func testCatalogQueryItemsIncludeWebParameters() {
        let queryItems = WebPlayerHeaders.catalogSongQueryItems()

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "platform", value: "web")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "format[resources]", value: "map")))

        let queryOut = """
        QueryItems:
        \(queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "\n"))

        """
        try? Self.appendTestOutput(queryOut)
    }

    func testTokenManagerUsesInjectedStorage() async throws {
        final class TokenBox: @unchecked Sendable {
            var token: String?
        }

        let box = TokenBox()
        let storage = TokenStorage(
            save: { value, _ in box.token = value },
            load: { _ in box.token },
            delete: { _ in box.token = nil }
        )

        let tokenManager = TokenManager(storage: storage, storageKey: "token")
        await tokenManager.setBearerToken("one-two-three", source: "manual")

        let tokenState = await tokenManager.tokenState()
        let storedToken = tokenState?.bearerToken
        let authorizationHeader = await tokenManager.authorizationHeaderValue()
        let storedPayload = box.token

        XCTAssertEqual(storedToken, "one-two-three")
        XCTAssertEqual(authorizationHeader, "Bearer one-two-three")
        XCTAssertNotNil(storedPayload)

        if let storedPayload, let data = storedPayload.data(using: .utf8) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let persistedState = try decoder.decode(TokenState.self, from: data)

            XCTAssertEqual(persistedState.bearerToken, "one-two-three")
            XCTAssertEqual(persistedState.source, "manual")
        } else {
            XCTFail("Expected the token payload to be persisted")
        }

        await tokenManager.clearBearerToken()
        let clearedToken = await tokenManager.bearerToken()

        XCTAssertNil(clearedToken)

        let tokenOut = """
        StoredToken: \(storedToken ?? "nil")
        AuthorizationHeader: \(authorizationHeader ?? "nil")
        ClearedToken: \(clearedToken ?? "nil")

        """
        try? Self.appendTestOutput(tokenOut)
    }

    func testTokenExtractorRefreshesAccordingToPolicy() async throws {
        actor CountingExtractor: BearerTokenExtractor {
            private var count = 0

            func extractBearerToken() async throws -> String {
                count += 1

    func testItunesKitAuthorizationHeaderUsesTokenSource() async throws {
        let client = iTunesKit(
            tokenSource: ClosureBearerTokenExtractor {
                "facade-token"
            },
            tokenRefreshPolicy: .always
        )

        let authorizationHeader = await client.authorizationHeaderValue()

        XCTAssertEqual(authorizationHeader, "Bearer facade-token")
    }

    func testItunesKitAuthorizationHeaderUsesManualToken() async throws {
        let client = iTunesKit()
        await client.setBearerToken("manual-token", source: "manual")

        let authorizationHeader = await client.authorizationHeaderValue()

        XCTAssertEqual(authorizationHeader, "Bearer manual-token")
    }
                return "token-\(count)"
            }
        }

        final class PayloadBox: @unchecked Sendable {
            var payload: String?
        }

        final class DateBox: @unchecked Sendable {
            var date: Date

            init(date: Date) {
                self.date = date
            }
        }

        let extractor = CountingExtractor()
        let payloadBox = PayloadBox()
        let storage = TokenStorage(
            save: { value, _ in payloadBox.payload = value },
            load: { _ in payloadBox.payload },
            delete: { _ in payloadBox.payload = nil }
        )
        let tokenManager = TokenManager(storage: storage, storageKey: "token-lifecycle")
        let dateBox = DateBox(date: Date(timeIntervalSince1970: 1_700_000_000))

        let tokenExtractor = TokenExtractor(
            manager: tokenManager,
            source: extractor,
            refreshPolicy: .after(10),
            now: { dateBox.date }
        )

        let firstToken = try await tokenExtractor.bearerToken()
        let secondToken = try await tokenExtractor.bearerToken()

        dateBox.date = dateBox.date.addingTimeInterval(11)
        let thirdToken = try await tokenExtractor.bearerToken()

        XCTAssertEqual(firstToken, "token-1")
        XCTAssertEqual(secondToken, "token-1")
        XCTAssertEqual(thirdToken, "token-2")

        let authorizationHeader = try await tokenExtractor.authorizationHeaderValue()
        XCTAssertEqual(authorizationHeader, "Bearer token-2")

        let lifecycleOut = """
        FirstToken: \(firstToken)
        SecondToken: \(secondToken)
        ThirdToken: \(thirdToken)
        AuthorizationHeader: \(authorizationHeader)

        """
        try? Self.appendTestOutput(lifecycleOut)
    }

    private func decodeSampleCatalogResponse() throws -> CatalogResponse {
        let json = """
        {
            "data": [
                {
                    "id": "1699712644",
                    "type": "songs",
                    "href": "/v1/catalog/us/songs/1699712644?l=en-US"
                }
            ],
            "resources": {
                "albums": {
                    "1699712635": {
                        "id": "1699712635",
                        "type": "albums",
                        "href": "/v1/catalog/us/albums/1699712635?l=en-US",
                        "attributes": {
                            "editorialVideo": {
                                "motionDetailSquare": {
                                    "previewFrame": {
                                        "bgColor": "000000",
                                        "url": "https://is1-ssl.mzstatic.com/image/thumb/Video126/v4/2b/cb/c5/2bcbc5fb-590a-a991-00a9-23e09da46860/Jobcca42104-faad-4d2d-8766-c7cafe52cdf0-153498700-PreviewImage_preview_image_nonvideo_sdr-Time1690571006394.png/{w}x{h}bb.{f}"
                                    },
                                    "video": "https://mvod.itunes.apple.com/itunes-assets/HLSMusic116/v4/7d/62/ab/7d62ab9b-3d87-5ce6-3076-76beef4a1d1a/P606895970_default.m3u8"
                                },
                                "motionDetailTall": {
                                    "previewFrame": {
                                        "bgColor": "000000",
                                        "url": "https://is1-ssl.mzstatic.com/image/thumb/Video126/v4/c4/a1/3f/c4a13f64-441f-1ce5-0744-ce935e48bc0c/Job630c325d-096c-4e90-86ba-02e7b4e97f58-153498701-PreviewImage_preview_image_nonvideo_sdr-Time1690571002753.png/{w}x{h}bb.{f}"
                                    },
                                    "video": "https://mvod.itunes.apple.com/itunes-assets/HLSMusic126/v4/e2/a2/96/e2a296a2-f0b7-e951-b543-c0795f99d661/P606897945_default.m3u8"
                                }
                            }
                        }
                    }
                },
                "songs": {
                    "1699712644": {
                        "id": "1699712644",
                        "type": "songs",
                        "href": "/v1/catalog/us/songs/1699712644?l=en-US",
                        "attributes": {
                            "hasLyrics": true,
                            "name": "MY EYES",
                            "url": "https://music.apple.com/us/album/my-eyes/1699712635?i=1699712644"
                        },
                        "relationships": {
                            "albums": {
                                "href": "/v1/catalog/us/songs/1699712644/albums?l=en-US",
                                "data": [
                                    {
                                        "id": "1699712635",
                                        "type": "albums",
                                        "href": "/v1/catalog/us/albums/1699712635?l=en-US"
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
        """

        return try JSONDecoder().decode(CatalogResponse.self, from: Data(json.utf8))
    }

    // Helper to append test outputs to a file in temporary directory
    private static func appendTestOutput(_ text: String) throws {
        let fm = FileManager.default
        // Prefer the user's Downloads directory; fall back to temporary directory.
        let downloadsURL = fm.urls(for: .downloadsDirectory, in: .userDomainMask).first
        let dir = downloadsURL ?? fm.temporaryDirectory
        let fileURL = dir.appendingPathComponent("iTunesKit_test_output.txt")

        if !fm.fileExists(atPath: fileURL.path) {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } else {
            let handle = try FileHandle(forWritingTo: fileURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            if let data = text.data(using: .utf8) {
                try handle.write(contentsOf: data)
            }
        }
    }
}
