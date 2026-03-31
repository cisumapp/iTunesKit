package aaravgupta.ituneskit

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

public class iTunesWebTokenService(
    private val session: OkHttpClient = NetworkDefaults.defaultOkHttpClient(),
    cacheFile: File? = null,
    private val cacheDirectoryProvider: iTunesCacheDirectoryProvider = SystemCacheDirectoryProvider,
    private val nowProvider: () -> Long = { System.currentTimeMillis() },
    private val logger: (String) -> Unit = { println(it) }
) {
    @Serializable
    private data class CachedTokenState(
        val token: String? = null,
        val tokenExpiry: String? = null,
        val lastScrapeDate: String? = null
    )

    private val json: Json = NetworkDefaults.defaultJson
    private val mutex: Mutex = Mutex()
    private val cacheFile: File = cacheFile ?: defaultCacheFile(cacheDirectoryProvider)

    private var cachedToken: String? = null
    private var tokenExpiryMillis: Long? = null
    private var lastScrapeDateMillis: Long? = null

    init {
        val state = loadState()
        if (state != null) {
            cachedToken = state.token
            tokenExpiryMillis = state.tokenExpiry?.let(Iso8601DateCodec::parse)
            lastScrapeDateMillis = state.lastScrapeDate?.let(Iso8601DateCodec::parse)
        }
    }

    public suspend fun fetchToken(): String = mutex.withLock {
        val now = nowProvider()

        validCachedToken(now)?.let { return@withLock it }

        val lastScrapeDate = lastScrapeDateMillis
        if (lastScrapeDate != null && (now - lastScrapeDate) < MIN_SCRAPE_INTERVAL_MILLIS) {
            logger("iTunesKit: Rate limiting scrape. Using last known token (or failing if none).")
            validCachedToken(now)?.let { return@withLock it }
            throw iTunesKitException.CannotConnectToHost(
                "Scrape throttled and no valid cached token available"
            )
        }

        logger("iTunesKit: Scraping Apple Music Web Player...")
        if (Secrets.webNewURL.toHttpUrlOrNull() == null) {
            throw iTunesKitException.BadUrl(Secrets.webNewURL)
        }

        val scrapeDate = now
        lastScrapeDateMillis = scrapeDate
        persistState()

        val html = fetchText(
            url = Secrets.webNewURL,
            headers = mapOf("User-Agent" to Secrets.userAgent)
        )

        val jsPath = extractJavaScriptPath(html)
            ?: throw iTunesKitException.CannotParseResponse()

        val jsURL = "${Secrets.webURL}$jsPath"
    logger("iTunesKit: Fetching application script: $jsURL")

        val jsContent = fetchText(
            url = jsURL,
            headers = mapOf("User-Agent" to Secrets.userAgent)
        )

        val token = findToken(jsContent)
            ?: throw iTunesKitException.CannotParseResponse()

        cachedToken = token
        tokenExpiryMillis = nowProvider() + TOKEN_LIFETIME_MILLIS
        lastScrapeDateMillis = scrapeDate
        persistState()

        logger("iTunesKit: Successfully obtained devToken from script")
        token
    }

    private suspend fun fetchText(url: String, headers: Map<String, String>): String {
        val parsedURL = url.toHttpUrlOrNull() ?: throw iTunesKitException.BadUrl(url)
        val requestBuilder = Request.Builder().url(parsedURL).get()

        for ((name, value) in headers) {
            requestBuilder.header(name, value)
        }

        val request = requestBuilder.build()

        return withContext(Dispatchers.IO) {
            session.newCall(request).execute().use { response ->
                val responseBytes = response.body?.bytes() ?: ByteArray(0)
                if (!response.isSuccessful) {
                    throw iTunesKitException.BadServerResponse(
                        statusCode = response.code,
                        url = url,
                        responseBody = responseBytes.toString(Charsets.UTF_8).ifBlank { null }
                    )
                }

                responseBytes.toString(Charsets.UTF_8)
            }
        }
    }

    private fun extractJavaScriptPath(html: String): String? {
        return JS_BUNDLE_PATTERN.find(html)?.value
    }

    private fun findToken(text: String): String? {
        for (match in TOKEN_PATTERN.findAll(text)) {
            val token = match.value
            if (token.count { it == '.' } >= 2) {
                return token
            }
        }
        return null
    }

    private fun validCachedToken(now: Long): String? {
        val token = cachedToken
        val expiry = tokenExpiryMillis
        if (token != null && expiry != null && expiry > now) {
            return token
        }
        return null
    }

    private fun persistState() {
        val state = CachedTokenState(
            token = cachedToken,
            tokenExpiry = tokenExpiryMillis?.let(Iso8601DateCodec::format),
            lastScrapeDate = lastScrapeDateMillis?.let(Iso8601DateCodec::format)
        )

        try {
            cacheFile.parentFile?.mkdirs()
            val encoded = json.encodeToString(CachedTokenState.serializer(), state)
            cacheFile.writeText(encoded)
        } catch (error: Throwable) {
            logger("iTunesKit: Failed to persist devToken cache: $error")
        }
    }

    private fun loadState(): CachedTokenState? {
        return try {
            if (!cacheFile.exists()) {
                null
            } else {
                val text = cacheFile.readText()
                json.decodeFromString(CachedTokenState.serializer(), text)
            }
        } catch (_: Throwable) {
            null
        }
    }

    public companion object {
        private const val MIN_SCRAPE_INTERVAL_MILLIS: Long = 3_600_000L
        private const val TOKEN_LIFETIME_MILLIS: Long = 7_200_000L

        private val JS_BUNDLE_PATTERN = Regex("/assets/index~[a-zA-Z0-9]+\\.js")
        private val TOKEN_PATTERN = Regex("eyJ[a-zA-Z0-9._-]{200,}")

        @Volatile
        private var sharedCacheDirectoryProvider: iTunesCacheDirectoryProvider = SystemCacheDirectoryProvider

        @Volatile
        private var sharedInstance: iTunesWebTokenService? = null

        private fun defaultCacheFile(provider: iTunesCacheDirectoryProvider): File {
            return provider.cacheDirectory()
                .resolve("iTunesKit")
                .resolve("web-token-cache.json")
        }

        @JvmStatic
        public fun configureSharedCacheDirectoryProvider(provider: iTunesCacheDirectoryProvider) {
            synchronized(this) {
                sharedCacheDirectoryProvider = provider
                sharedInstance = null
            }
        }

        @JvmStatic
        public val shared: iTunesWebTokenService
            get() = synchronized(this) {
                sharedInstance ?: iTunesWebTokenService(
                    cacheDirectoryProvider = sharedCacheDirectoryProvider
                ).also { sharedInstance = it }
            }
    }
}

private object Iso8601DateCodec {
    private val utcTimeZone: TimeZone = TimeZone.getTimeZone("UTC")
    private val formats: List<String> = listOf(
        "yyyy-MM-dd'T'HH:mm:ss.SSSX",
        "yyyy-MM-dd'T'HH:mm:ssX"
    )

    fun format(epochMillis: Long): String {
        val formatter = SimpleDateFormat(formats.first(), Locale.US)
        formatter.timeZone = utcTimeZone
        return formatter.format(Date(epochMillis))
    }

    fun parse(value: String): Long? {
        for (pattern in formats) {
            val formatter = SimpleDateFormat(pattern, Locale.US)
            formatter.timeZone = utcTimeZone
            val parsed = formatter.parse(value)
            if (parsed != null) {
                return parsed.time
            }
        }

        return null
    }
}