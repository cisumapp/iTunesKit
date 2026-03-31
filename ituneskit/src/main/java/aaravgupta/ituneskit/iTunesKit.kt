package aaravgupta.ituneskit

import java.net.URL

public data class iTunesMotionArtworkResolution(
    val sourceURL: URL,
    val trackID: Int,
    val collectionID: Int?,
    val catalogAlbumID: String?
)

public class iTunesKit(
    private val searchService: SearchService = SearchService(),
    private val makeWebCatalogService: () -> WebCatalogService = {
        WebCatalogService(client = iTunesWebServiceClient())
    }
) : iTunesClient {

    override suspend fun searchSongs(term: String): List<iTunesSearchResult> {
        val response = search(term = term, country = "us", media = "music", limit = 50)
        return response.results
    }

    override suspend fun search(
        term: String,
        country: String,
        media: String,
        limit: Int
    ): iTunesSearchResponse {
        return searchService.search(
            term = term,
            country = country,
            media = media,
            limit = limit
        )
    }

    public suspend fun resolveMotionArtwork(
        term: String,
        country: String = "us"
    ): iTunesMotionArtworkResolution? {
        val searchResponse = search(term = term, country = country, media = "music", limit = 1)
        val searchMatch = searchResponse.results.firstOrNull() ?: return null
        val trackID = searchMatch.trackId ?: return null

        val songID = trackID.toString()
        val catalogService = makeWebCatalogService()
        val catalogResponse = catalogService.fetchSongDetails(songId = songID, storefront = country)

        val selection = selectMotionArtwork(catalogResponse, preferredSongID = songID) ?: return null

        return iTunesMotionArtworkResolution(
            sourceURL = selection.sourceURL,
            trackID = trackID,
            collectionID = searchMatch.collectionId,
            catalogAlbumID = selection.albumID
        )
    }

    internal data class MotionArtworkSelection(
        val sourceURL: URL,
        val albumID: String
    )

    public companion object {
        @JvmStatic
        internal fun selectMotionArtwork(
            response: iTunesCatalogResponse,
            preferredSongID: String?
        ): MotionArtworkSelection? {
            for (albumID in preferredAlbumIDs(response, preferredSongID)) {
                val album = response.resources.albums[albumID] ?: continue
                val sourceURL = firstMotionArtworkURL(album.attributes.editorialVideo) ?: continue
                return MotionArtworkSelection(sourceURL = sourceURL, albumID = albumID)
            }

            return null
        }

        private fun preferredAlbumIDs(
            response: iTunesCatalogResponse,
            preferredSongID: String?
        ): List<String> {
            val albumIDs = mutableListOf<String>()
            val fallbackSongID = response.data.firstOrNull { it.type == "songs" }?.id
            val targetSongID = preferredSongID ?: fallbackSongID

            val relationships = if (targetSongID != null) {
                response.resources.songs[targetSongID]?.relationships?.albums?.data
            } else {
                null
            }

            if (relationships != null) {
                for (relationship in relationships) {
                    val albumID = relationship.id.trim()
                    if (albumID.isNotEmpty() && albumID !in albumIDs) {
                        albumIDs += albumID
                    }
                }
            }

            for (albumID in response.resources.albums.keys) {
                if (albumID !in albumIDs) {
                    albumIDs += albumID
                }
            }

            return albumIDs
        }

        private fun firstMotionArtworkURL(editorialVideo: EditorialVideo): URL? {
            val candidates = listOf(
                editorialVideo.motionDetailTall.video,
                editorialVideo.motionTallVideo3X4.video,
                editorialVideo.motionDetailSquare.video,
                editorialVideo.motionSquareVideo1X1.video
            )

            for (candidate in candidates) {
                runCatching { URL(candidate) }
                    .onSuccess { return it }
            }

            return null
        }
    }
}