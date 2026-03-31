package aaravgupta.ituneskit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request

public class iTunesWebServiceClient(
    private val tokenService: iTunesWebTokenService = iTunesWebTokenService.shared,
    private val baseURL: String = Secrets.ampBaseURL,
    private val session: OkHttpClient = NetworkDefaults.defaultOkHttpClient(),
    private val json: Json = NetworkDefaults.defaultJson,
    private val nowProvider: () -> Long = { System.currentTimeMillis() }
) {
    private val sendMutex: Mutex = Mutex()
    private var lastRequestTimeMillis: Long? = null
    private val minRequestIntervalMillis: Long = 500L

    public suspend inline fun <reified T> send(
        endpoint: String,
        queryItems: List<URLQueryItem> = emptyList()
    ): T {
        return sendDecoded(endpoint, queryItems, serializer())
    }

    @PublishedApi
    internal suspend fun <T> sendDecoded(
        endpoint: String,
        queryItems: List<URLQueryItem>,
        deserializer: KSerializer<T>
    ): T = sendMutex.withLock {
        val lastTime = lastRequestTimeMillis
        if (lastTime != null) {
            val elapsed = nowProvider() - lastTime
            if (elapsed < minRequestIntervalMillis) {
                delay(minRequestIntervalMillis - elapsed)
            }
        }

        val token = tokenService.fetchToken()
        val url = buildURL(endpoint, queryItems)

        val request = Request.Builder()
            .url(url)
            .get()
            .header("Authorization", "Bearer $token")
            .header("User-Agent", Secrets.userAgent)
            .header("Origin", Secrets.webURL)
            .header("Referer", "${Secrets.webURL}/")
            .header("Accept", "*/*")
            .header("Accept-Language", "en-US,en;q=0.9")
            .header("Sec-Fetch-Dest", "empty")
            .header("Sec-Fetch-Mode", "cors")
            .header("Sec-Fetch-Site", "same-site")
            .build()

        val payload = withContext(Dispatchers.IO) {
            session.newCall(request).execute().use { response ->
                ResponsePayload(
                    statusCode = response.code,
                    body = response.body?.bytes() ?: ByteArray(0)
                )
            }
        }

        lastRequestTimeMillis = nowProvider()

        if (payload.statusCode !in 200..299) {
            throw iTunesKitException.BadServerResponse(
                statusCode = payload.statusCode,
                url = url.toString(),
                responseBody = payload.body.toString(Charsets.UTF_8).ifBlank { null }
            )
        }

        val text = payload.body.toString(Charsets.UTF_8)
        return@withLock try {
            json.decodeFromString(deserializer, text)
        } catch (error: SerializationException) {
            throw iTunesKitException.CannotParseResponse(error)
        }
    }

    private fun buildURL(endpoint: String, queryItems: List<URLQueryItem>): HttpUrl {
        val base = baseURL.toHttpUrlOrNull() ?: throw iTunesKitException.BadUrl(baseURL)
        val builder = base.newBuilder()

        endpoint.split('/')
            .filter { it.isNotBlank() }
            .forEach(builder::addPathSegment)

        queryItems.forEach { builder.addQueryParameter(it.name, it.value) }
        return builder.build()
    }

    private data class ResponsePayload(
        val statusCode: Int,
        val body: ByteArray
    )
}