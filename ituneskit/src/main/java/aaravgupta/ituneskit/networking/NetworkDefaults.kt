package aaravgupta.ituneskit

import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient

internal object NetworkDefaults {
    internal val defaultJson: Json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
    }

    internal fun defaultOkHttpClient(): OkHttpClient = OkHttpClient.Builder().build()
}