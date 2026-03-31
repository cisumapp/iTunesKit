package aaravgupta.ituneskit

import okhttp3.OkHttpClient

public class SearchService(
    private val client: NetworkClient
) {
    public constructor(session: OkHttpClient = NetworkDefaults.defaultOkHttpClient()) : this(
        client = NetworkClient(baseURL = Secrets.itunesBaseURL, session = session)
    )

    public suspend fun search(
        term: String,
        country: String = "us",
        media: String? = null,
        entity: String? = null,
        attribute: String? = null,
        limit: Int = 50,
        lang: String = "en_us",
        version: Int = 2,
        explicit: Boolean = true
    ): iTunesSearchResponse {
        val queryItems = mutableListOf(
            URLQueryItem("term", term),
            URLQueryItem("country", country),
            URLQueryItem("limit", limit.toString()),
            URLQueryItem("lang", lang),
            URLQueryItem("version", version.toString()),
            URLQueryItem("explicit", if (explicit) "Yes" else "No")
        )

        if (media != null) queryItems += URLQueryItem("media", media)
        if (entity != null) queryItems += URLQueryItem("entity", entity)
        if (attribute != null) queryItems += URLQueryItem("attribute", attribute)

        return client.send(endpoint = "search", queryItems = queryItems)
    }

    public suspend fun lookup(
        id: String? = null,
        amgArtistId: String? = null,
        amgAlbumId: String? = null,
        amgVideoId: String? = null,
        upc: String? = null,
        isbn: String? = null,
        entity: String? = null,
        limit: Int? = null,
        sort: String? = null
    ): iTunesSearchResponse {
        val queryItems = mutableListOf<URLQueryItem>()

        if (id != null) queryItems += URLQueryItem("id", id)
        if (amgArtistId != null) queryItems += URLQueryItem("amgArtistId", amgArtistId)
        if (amgAlbumId != null) queryItems += URLQueryItem("amgAlbumId", amgAlbumId)
        if (amgVideoId != null) queryItems += URLQueryItem("amgVideoId", amgVideoId)
        if (upc != null) queryItems += URLQueryItem("upc", upc)
        if (isbn != null) queryItems += URLQueryItem("isbn", isbn)
        if (entity != null) queryItems += URLQueryItem("entity", entity)
        if (limit != null) queryItems += URLQueryItem("limit", limit.toString())
        if (sort != null) queryItems += URLQueryItem("sort", sort)

        return client.send(endpoint = "lookup", queryItems = queryItems)
    }
}