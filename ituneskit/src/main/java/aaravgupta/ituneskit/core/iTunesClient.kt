package aaravgupta.ituneskit

public interface iTunesClient {
    public suspend fun searchSongs(term: String): List<iTunesSearchResult>

    public suspend fun search(
        term: String,
        country: String,
        media: String,
        limit: Int
    ): iTunesSearchResponse
}