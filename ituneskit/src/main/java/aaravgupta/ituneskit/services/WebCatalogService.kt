package aaravgupta.ituneskit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request

public class WebCatalogService(
    private val client: iTunesWebServiceClient,
    private val session: OkHttpClient = NetworkDefaults.defaultOkHttpClient(),
    private val json: Json = NetworkDefaults.defaultJson
) {
    public suspend fun fetchSongDetails(
        songId: String,
        storefront: String = "us"
    ): iTunesCatalogResponse {
        val endpoint = "catalog/$storefront/songs/$songId"
        val queryItems = listOf(
            URLQueryItem("art[url]", "f"),
            URLQueryItem("fields[albums]", "editorialVideo"),
            URLQueryItem("fields[songs]", "name,url,hasLyrics"),
            URLQueryItem("format[resources]", "map"),
            URLQueryItem("include[songs]", "albums"),
            URLQueryItem("l", Secrets.defaultLanguage),
            URLQueryItem("omit[resource]", "autos"),
            URLQueryItem("platform", "web")
        )

        return client.send(endpoint = endpoint, queryItems = queryItems)
    }

    public suspend fun search(term: String, storefront: String = "us"): String? {
        val baseURL = "${Secrets.itunesBaseURL}/search"
        val parsed = baseURL.toHttpUrlOrNull() ?: throw iTunesKitException.BadUrl(baseURL)
        val url = parsed.newBuilder()
            .addQueryParameter("term", term)
            .addQueryParameter("country", storefront)
            .addQueryParameter("media", "music")
            .addQueryParameter("limit", "1")
            .build()

        val request = Request.Builder().url(url).get().build()

        val data = withContext(Dispatchers.IO) {
            session.newCall(request).execute().use { response ->
                response.body?.bytes() ?: ByteArray(0)
            }
        }

        return try {
            val payload = json.decodeFromString(iTunesSearchResponse.serializer(), data.toString(Charsets.UTF_8))
            payload.results.firstOrNull()?.trackId?.toString()
        } catch (error: SerializationException) {
            throw iTunesKitException.CannotParseResponse(error)
        }
    }
}