package aaravgupta.ituneskit

import java.io.IOException

public sealed class iTunesKitException(message: String, cause: Throwable? = null) :
    IOException(message, cause) {

    public class BadUrl(public val url: String?) :
        iTunesKitException("Bad URL: ${url ?: "unknown"}")

    public class BadServerResponse(
        public val statusCode: Int,
        public val url: String?,
        public val responseBody: String? = null
    ) : iTunesKitException(
        buildString {
            append("Bad server response (")
            append(statusCode)
            append(")")
            if (!url.isNullOrBlank()) {
                append(" for ")
                append(url)
            }
            if (!responseBody.isNullOrBlank()) {
                append(". Body: ")
                append(responseBody)
            }
        }
    )

    public class CannotDecodeRawData(cause: Throwable? = null) :
        iTunesKitException("Cannot decode raw data", cause)

    public class CannotParseResponse(cause: Throwable? = null) :
        iTunesKitException("Cannot parse response", cause)

    public class CannotConnectToHost(message: String) :
        iTunesKitException(message)
}