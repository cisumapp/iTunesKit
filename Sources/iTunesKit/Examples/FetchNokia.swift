import Foundation
import iTunesKit

@main
struct FetchNokia {
    static func main() async {
        iTunesLog.debug(" Starting Apple Music Web API Demo...")

        let webClient = iTunesWebServiceClient()
        let catalogService = WebCatalogService(client: webClient)

        do {
            // 1. Search for "nokia" by Drake
            let searchTerm = "drake nokia"
            iTunesLog.debug(" Searching for: \(searchTerm)...")

            if let songId = try await catalogService.search(term: searchTerm) {
                iTunesLog.debug(" Found Song ID: \(songId)")

                // 2. Fetch details including editorial video
                iTunesLog.debug(" Fetching catalog details for song \(songId)...")
                let response = try await catalogService.fetchSongDetails(songId: songId)

                // 3. Extract .motionDetailTall
                if let song = response.resources.songs[songId],
                   let albumId = song.relationships?.albums.data.first?.id,
                   let album = response.resources.albums[albumId]
                {
                    let videoUrl = album.attributes.editorialVideo.motionDetailTall.video
                    iTunesLog.debug("\n SUCCESS! Found motionDetailTall for '\(song.attributes.name)':")
                    iTunesLog.debug(" Video URL: \(videoUrl)")

                    let previewUrl = album.attributes.editorialVideo.motionDetailSquare.previewFrame.url
                    iTunesLog.debug(" Preview Frame: \(previewUrl)")

                } else {
                    iTunesLog.debug(" Could not find editorial video in the response resources.")
                }
            } else {
                iTunesLog.debug(" Could not find song ID for '\(searchTerm)'.")
            }

        } catch {
            iTunesLog.debug(" Error during execution: \(error)")
        }
    }
}

// import Foundation
// import iTunesKit

// @main
// struct VerifyCaching {
//     static func main() async {
//         iTunesLog.debug(" Verifying Token Caching Logic...")

//         let client = iTunesWebServiceClient()
//         let catalog = WebCatalogService(client: client)

//         do {
//             // First call: Should trigger scraping
//             iTunesLog.debug(" First request...")
//             _ = try await catalog.search(term: "drake")

//             // Second call: Should reuse cached token
//             iTunesLog.debug("\n Second request...")
//             _ = try await catalog.search(term: "taylor swift")

//             iTunesLog.debug("\n Verification complete. Check logs for redundant 'Scraping' messages.")
//         } catch {
//             iTunesLog.debug(" Error: \(error)")
//         }
//     }
// }
