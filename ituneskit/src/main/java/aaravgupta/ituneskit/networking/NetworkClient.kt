package aaravgupta.ituneskit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.KSerializer
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.serializer
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

public enum class HTTPMethod(public val rawValue: String) {
    GET("GET"),
    POST("POST"),
    PUT("PUT"),
    DELETE("DELETE")
}

public class NetworkClient(
    private val baseURL: String,
    private val session: OkHttpClient = NetworkDefaults.defaultOkHttpClient(),
    private val json: Json = NetworkDefaults.defaultJson
) {
    public suspend inline fun <reified T> send(
        endpoint: String,
        method: HTTPMethod = HTTPMethod.GET,
        headers: Map<String, String> = emptyMap(),
        queryItems: List<URLQueryItem> = emptyList(),
        body: ByteArray? = null
    ): T {
        return sendDecoded(endpoint, method, headers, queryItems, body, serializer())
    }

    @PublishedApi
    internal suspend fun <T> sendDecoded(
        endpoint: String,
        method: HTTPMethod,
        headers: Map<String, String>,
        queryItems: List<URLQueryItem>,
        body: ByteArray?,
        deserializer: KSerializer<T>
    ): T {
        val data = request(endpoint, method, headers, queryItems, body)
        val payload = data.toString(Charsets.UTF_8)

        return try {
            json.decodeFromString(deserializer, payload)
        } catch (error: SerializationException) {
            throw iTunesKitException.CannotParseResponse(error)
        }
    }

    public suspend fun request(
        endpoint: String,
        method: HTTPMethod = HTTPMethod.GET,
        headers: Map<String, String> = emptyMap(),
        queryItems: List<URLQueryItem> = emptyList(),
        body: ByteArray? = null
    ): ByteArray {
        val finalURL = buildURL(endpoint, queryItems)
        val finalMethod = if (method == HTTPMethod.GET && body != null) HTTPMethod.POST else method
        val jsonMediaType = "application/json; charset=utf-8".toMediaTypeOrNull()

        val requestBody = when {
            body != null -> body.toRequestBody(jsonMediaType)
            finalMethod == HTTPMethod.POST || finalMethod == HTTPMethod.PUT ->
                ByteArray(0).toRequestBody(jsonMediaType)

            else -> null
        }

        val requestBuilder = Request.Builder()
            .url(finalURL)
            .method(finalMethod.rawValue, requestBody)
            .header("Content-Type", "application/json")

        for ((key, value) in headers) {
            requestBuilder.header(key, value)
        }

        val request = requestBuilder.build()

        return withContext(Dispatchers.IO) {
            session.newCall(request).execute().use { response ->
                val responseBytes = response.body?.bytes() ?: ByteArray(0)
                if (!response.isSuccessful) {
                    val errorBody = responseBytes.toString(Charsets.UTF_8).ifBlank { null }
                    throw iTunesKitException.BadServerResponse(
                        statusCode = response.code,
                        url = request.url.toString(),
                        responseBody = errorBody
                    )
                }

                responseBytes
            }
        }
    }

    public suspend fun get(endpoint: String, body: ByteArray? = null): ByteArray {
        return request(endpoint, method = HTTPMethod.GET, body = body)
    }

    private fun buildURL(endpoint: String, queryItems: List<URLQueryItem>): HttpUrl {
        val base = baseURL.toHttpUrlOrNull() ?: throw iTunesKitException.BadUrl(baseURL)
        val builder = base.newBuilder()

        if (endpoint.isNotBlank()) {
            endpoint.split('/')
                .filter { it.isNotBlank() }
                .forEach(builder::addPathSegment)
        }

        for (queryItem in queryItems) {
            builder.addQueryParameter(queryItem.name, queryItem.value)
        }

        return builder.build()
    }
}