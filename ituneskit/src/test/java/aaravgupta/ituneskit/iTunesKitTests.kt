package aaravgupta.ituneskit

import kotlinx.coroutines.test.runTest
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.Interceptor
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okhttp3.ResponseBody.Companion.toResponseBody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Test
import java.io.File
import java.net.URL
import java.util.UUID
import java.util.concurrent.atomic.AtomicInteger

class iTunesKitTests {
    @Test
    fun testSearchServiceDecodesSearchResponse() = runTest {
        val session = makeSession { request ->
            if (request.url.toString().contains("itunes.apple.com/search")) {
                stubResponse(
                    body = """
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
                    """.trimIndent()
                )
            } else {
                stubResponse(statusCode = 404)
            }
        }

        val service = SearchService(session = session)
        val response = service.search(term = "test song", media = "music", limit = 1)

        assertEquals(1, response.resultCount)
        assertEquals(42, response.results.firstOrNull()?.trackId)
        assertEquals("Test Song", response.results.firstOrNull()?.trackName)
    }

    @Test
    fun testWebClientUsesPersistedTokenWithoutRescraping() = runTest {
        val token = makeFakeToken()
        val cacheFile = makeTemporaryCacheFile("web-token-cache.json")
        val requests = RequestTracker()

        val session = makeSession { request ->
            requests.increment()
            val url = request.url.toString()

            when {
                url == Secrets.webNewURL -> {
                    val html = "<html><head><script src=\"/assets/index~test.js\"></script></head><body></body></html>"
                    stubResponse(body = html, contentType = "text/html")
                }

                url == "https://music.apple.com/assets/index~test.js" -> {
                    val script = "const devToken = \"$token\";"
                    stubResponse(body = script, contentType = "application/javascript")
                }

                url.contains("amp-api.music.apple.com") -> {
                    assertEquals("Bearer $token", request.header("Authorization"))
                    stubResponse(body = """{ "message": "ok" }""")
                }

                else -> stubResponse(statusCode = 404)
            }
        }

        val firstClient = iTunesWebServiceClient(
            tokenService = iTunesWebTokenService(session = session, cacheFile = cacheFile),
            session = session
        )

        val firstResponse: EchoResponse = firstClient.send("test")
        assertEquals(EchoResponse(message = "ok"), firstResponse)
        assertEquals(3, requests.currentValue())

        val secondClient = iTunesWebServiceClient(
            tokenService = iTunesWebTokenService(session = session, cacheFile = cacheFile),
            session = session
        )

        val secondResponse: EchoResponse = secondClient.send("test")
        assertEquals(EchoResponse(message = "ok"), secondResponse)
        assertEquals(4, requests.currentValue())
    }

    @Test
    fun testTokenServiceCachesAcrossInstances() = runTest {
        val token = makeFakeToken()
        val cacheFile = makeTemporaryCacheFile("token-cache.json")
        val requests = RequestTracker()

        val session = makeSession { request ->
            requests.increment()
            val url = request.url.toString()

            when {
                url == Secrets.webNewURL -> {
                    val html = "<html><head><script src=\"/assets/index~test.js\"></script></head><body></body></html>"
                    stubResponse(body = html, contentType = "text/html")
                }

                url == "https://music.apple.com/assets/index~test.js" -> {
                    val script = "const devToken = \"$token\";"
                    stubResponse(body = script, contentType = "application/javascript")
                }

                else -> stubResponse(statusCode = 404)
            }
        }

        val firstService = iTunesWebTokenService(session = session, cacheFile = cacheFile)
        val firstToken = firstService.fetchToken()
        assertEquals(token, firstToken)
        assertEquals(2, requests.currentValue())

        val secondService = iTunesWebTokenService(session = session, cacheFile = cacheFile)
        val secondToken = secondService.fetchToken()
        assertEquals(token, secondToken)
        assertEquals(2, requests.currentValue())
    }

    @Test
    fun testSelectMotionArtworkPrefersSongRelationshipAlbumOrder() {
        val relationshipURL = URL("https://example.com/relationship.m3u8")
        val fallbackURL = URL("https://example.com/fallback.m3u8")

        val response = makeCatalogResponse(
            songID = "42",
            relationshipAlbumID = "album-relationship",
            relationshipURL = relationshipURL,
            fallbackAlbumID = "album-fallback",
            fallbackURL = fallbackURL
        )

        val selection = iTunesKit.selectMotionArtwork(
            response = response,
            preferredSongID = "42"
        )

        assertNotNull(selection)
        assertEquals("album-relationship", selection?.albumID)
        assertEquals(relationshipURL, selection?.sourceURL)
    }

    @Test
    fun testResolveMotionArtworkReturnsCollectionAndAlbumMetadata() = runTest {
        val token = makeFakeToken()
        val cacheFile = makeTemporaryCacheFile("resolve-motion-token-cache.json")

        val relationshipURL = URL("https://example.com/relationship.m3u8")
        val fallbackURL = URL("https://example.com/fallback.m3u8")

        val catalogResponse = makeCatalogResponse(
            songID = "42",
            relationshipAlbumID = "album-relationship",
            relationshipURL = relationshipURL,
            fallbackAlbumID = "album-fallback",
            fallbackURL = fallbackURL
        )
        val catalogData = Json.encodeToString(catalogResponse)

        val session = makeSession { request ->
            val url = request.url.toString()
            when {
                url.contains("itunes.apple.com/search") -> {
                    stubResponse(
                        body = """
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
                        """.trimIndent()
                    )
                }

                url == Secrets.webNewURL -> {
                    val html = "<html><head><script src=\"/assets/index~test.js\"></script></head><body></body></html>"
                    stubResponse(body = html, contentType = "text/html")
                }

                url == "https://music.apple.com/assets/index~test.js" -> {
                    val script = "const devToken = \"$token\";"
                    stubResponse(body = script, contentType = "application/javascript")
                }

                url.contains("amp-api.music.apple.com/v1/catalog/us/songs/42") -> {
                    stubResponse(body = catalogData)
                }

                else -> stubResponse(statusCode = 404)
            }
        }

        val searchService = SearchService(session = session)
        val tokenService = iTunesWebTokenService(session = session, cacheFile = cacheFile)
        val webClient = iTunesWebServiceClient(tokenService = tokenService, session = session)
        val webCatalogService = WebCatalogService(client = webClient, session = session)
        val kit = iTunesKit(
            searchService = searchService,
            makeWebCatalogService = { webCatalogService }
        )

        val resolution = kit.resolveMotionArtwork(term = "test song test artist")

        assertNotNull(resolution)
        assertEquals(42, resolution?.trackID)
        assertEquals(9001, resolution?.collectionID)
        assertEquals("album-relationship", resolution?.catalogAlbumID)
        assertEquals(relationshipURL, resolution?.sourceURL)
    }

    private fun makeSession(handler: (Request) -> StubbedResponse): OkHttpClient {
        return OkHttpClient.Builder()
            .addInterceptor(
                Interceptor { chain ->
                    val request = chain.request()
                    val stub = handler(request)
                    Response.Builder()
                        .request(request)
                        .protocol(Protocol.HTTP_1_1)
                        .code(stub.statusCode)
                        .message("Stubbed")
                        .header("Content-Type", stub.contentType)
                        .body(
                            stub.body.toByteArray()
                                .toResponseBody(stub.contentType.toMediaTypeOrNull())
                        )
                        .build()
                }
            )
            .build()
    }

    private fun makeFakeToken(): String = "eyJ" + "a".repeat(210) + ".bbb.ccc"

    private fun makeTemporaryCacheFile(name: String): File {
        val directory = File(System.getProperty("java.io.tmpdir"), UUID.randomUUID().toString())
        directory.mkdirs()
        return directory.resolve(name)
    }

    private fun makeCatalogResponse(
        songID: String,
        relationshipAlbumID: String,
        relationshipURL: URL,
        fallbackAlbumID: String,
        fallbackURL: URL
    ): iTunesCatalogResponse {
        val relationshipAlbum = Album(
            id = relationshipAlbumID,
            type = "albums",
            href = "/v1/catalog/us/albums/$relationshipAlbumID",
            attributes = AlbumAttributes(
                editorialVideo = makeEditorialVideo(relationshipURL.toString())
            )
        )

        val fallbackAlbum = Album(
            id = fallbackAlbumID,
            type = "albums",
            href = "/v1/catalog/us/albums/$fallbackAlbumID",
            attributes = AlbumAttributes(
                editorialVideo = makeEditorialVideo(fallbackURL.toString())
            )
        )

        val song = Song(
            id = songID,
            type = "songs",
            href = "/v1/catalog/us/songs/$songID",
            attributes = SongAttributes(
                hasLyrics = true,
                name = "Test Song",
                url = "https://music.apple.com/us/song/test-song/$songID"
            ),
            relationships = SongRelationships(
                albums = RelationshipAlbums(
                    href = "/v1/catalog/us/songs/$songID/albums",
                    data = listOf(
                        iTunesCatalogData(
                            id = relationshipAlbumID,
                            type = "albums",
                            href = "/v1/catalog/us/albums/$relationshipAlbumID"
                        )
                    )
                )
            )
        )

        return iTunesCatalogResponse(
            data = listOf(
                iTunesCatalogData(
                    id = songID,
                    type = "songs",
                    href = "/v1/catalog/us/songs/$songID"
                )
            ),
            resources = Resources(
                albums = linkedMapOf(
                    fallbackAlbumID to fallbackAlbum,
                    relationshipAlbumID to relationshipAlbum
                ),
                songs = mapOf(songID to song)
            )
        )
    }

    private fun makeEditorialVideo(url: String): EditorialVideo {
        val motion = makeMotionVideo(url)
        return EditorialVideo(
            motionDetailSquare = motion,
            motionDetailTall = motion,
            motionSquareVideo1X1 = motion,
            motionTallVideo3X4 = motion
        )
    }

    private fun makeMotionVideo(url: String): MotionVideo {
        return MotionVideo(
            previewFrame = PreviewFrame(
                bgColor = "000000",
                hasP3 = false,
                height = 100,
                textColor1 = "FFFFFF",
                textColor2 = "FFFFFF",
                textColor3 = "FFFFFF",
                textColor4 = "FFFFFF",
                url = "https://example.com/preview.jpg",
                width = 100
            ),
            video = url
        )
    }

    private fun stubResponse(
        statusCode: Int = 200,
        body: String = "",
        contentType: String = "application/json"
    ): StubbedResponse {
        return StubbedResponse(statusCode = statusCode, body = body, contentType = contentType)
    }

    @Serializable
    private data class EchoResponse(val message: String)

    private data class StubbedResponse(
        val statusCode: Int,
        val body: String,
        val contentType: String
    )

    private class RequestTracker {
        private val count = AtomicInteger(0)

        fun increment() {
            count.incrementAndGet()
        }

        fun currentValue(): Int = count.get()
    }
}
