package aaravgupta.ituneskit

import okhttp3.OkHttpClient

public class CatalogService(
    session: OkHttpClient = NetworkDefaults.defaultOkHttpClient()
) {
    private val client: NetworkClient = NetworkClient(baseURL = Secrets.baseURL, session = session)

    // Parity note: Swift CatalogService currently exposes no public behavior.
    @Suppress("unused")
    private fun keepClientForParity(): NetworkClient = client
}