package aaravgupta.ituneskit.examples

import aaravgupta.ituneskit.WebCatalogService
import aaravgupta.ituneskit.iTunesWebServiceClient

/**
 * Kotlin port of the Swift FetchNokia demo.
 * This is a callable sample helper for apps/tests, not an app entrypoint.
 */
public object FetchNokiaExample {
    public suspend fun run(searchTerm: String = "drake nokia") {
        println("Starting Apple Music Web API demo...")

        val webClient = iTunesWebServiceClient()
        val catalogService = WebCatalogService(client = webClient)

        try {
            println("Searching for: $searchTerm")
            val songId = catalogService.search(term = searchTerm)

            if (songId == null) {
                println("Could not find a song ID for '$searchTerm'.")
                return
            }

            println("Found song ID: $songId")
            println("Fetching catalog details for song $songId")
            val response = catalogService.fetchSongDetails(songId = songId)

            val song = response.resources.songs[songId]
            val albumId = song?.relationships?.albums?.data?.firstOrNull()?.id
            val album = if (albumId != null) response.resources.albums[albumId] else null

            if (song != null && album != null) {
                val videoUrl = album.attributes.editorialVideo.motionDetailTall.video
                val previewUrl = album.attributes.editorialVideo.motionDetailSquare.previewFrame.url

                println("Found motionDetailTall for '${song.attributes.name}':")
                println("Video URL: $videoUrl")
                println("Preview Frame: $previewUrl")
            } else {
                println("Could not find editorial video in response resources.")
            }
        } catch (error: Throwable) {
            println("Error during execution: $error")
        }
    }
}
