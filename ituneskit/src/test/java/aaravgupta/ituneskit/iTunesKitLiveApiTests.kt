package aaravgupta.ituneskit

import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class iTunesKitLiveApiTests {
    @Test
    fun testLiveSearchService() = runBlocking {
        val response = withTimeout(45_000) {
            SearchService().search(
                term = "drake nokia",
                media = "music",
                limit = 1
            )
        }

        val first = response.results.firstOrNull()

        println("LIVE_SEARCH_RESULT_COUNT=${response.resultCount}")
        println("LIVE_SEARCH_FIRST_TRACK_ID=${first?.trackId}")
        println("LIVE_SEARCH_FIRST_TRACK_NAME=${first?.trackName}")
        println("LIVE_SEARCH_FIRST_ARTIST_NAME=${first?.artistName}")

        assertTrue("Expected at least one live search result", response.resultCount > 0)
        assertNotNull("Expected first live track to have a trackId", first?.trackId)
    }

    @Test
    fun testLiveResolveMotionArtwork() = runBlocking {
        val resolution = withTimeout(120_000) {
            iTunesKit().resolveMotionArtwork(term = "drake nokia")
        }

        println("LIVE_MOTION_ARTWORK_RESOLUTION=$resolution")

        assertNotNull(
            "Expected live motion artwork resolution for 'drake nokia'",
            resolution
        )
    }
}
