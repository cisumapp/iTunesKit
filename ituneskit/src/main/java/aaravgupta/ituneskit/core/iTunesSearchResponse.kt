package aaravgupta.ituneskit

import kotlinx.serialization.Serializable

@Serializable
public data class iTunesSearchResponse(
    val resultCount: Int,
    val results: List<iTunesSearchResult>
)

@Serializable
public data class iTunesSearchResult(
    val wrapperType: String? = null,
    val kind: String? = null,
    val artistId: Int? = null,
    val collectionId: Int? = null,
    val trackId: Int? = null,
    val artistName: String? = null,
    val collectionName: String? = null,
    val trackName: String? = null,
    val trackViewUrl: String? = null,
    val collectionViewUrl: String? = null,
    val previewUrl: String? = null,
    val artworkUrl30: String? = null,
    val artworkUrl60: String? = null,
    val artworkUrl100: String? = null,
    val releaseDate: String? = null,
    val country: String? = null,
    val currency: String? = null,
    val trackExplicitness: String? = null,
    val collectionExplicitness: String? = null,
    val contentAdvisoryRating: String? = null,
    val primaryGenreName: String? = null
)