import Foundation
import iTunesKit

@main
struct FetchNokia {
    static func main() async {
        print("🚀 Starting Apple Music Web API Demo...")
        
        let webClient = iTunesWebServiceClient()
        let catalogService = WebCatalogService(client: webClient)
        
        do {
            // 1. Search for "nokia" by Drake
            let searchTerm = "drake nokia"
            print("🔎 Searching for: \(searchTerm)...")
            
            if let songId = try await catalogService.search(term: searchTerm) {
                print("✅ Found Song ID: \(songId)")
                
                // 2. Fetch details including editorial video
                print("📦 Fetching catalog details for song \(songId)...")
                let response = try await catalogService.fetchSongDetails(songId: songId)
                
                // 3. Extract .motionDetailTall
                if let song = response.resources.songs[songId],
                   let albumId = song.relationships?.albums.data.first?.id,
                   let album = response.resources.albums[albumId] {
                    
                    let videoUrl = album.attributes.editorialVideo.motionDetailTall.video
                    print("\n✨ SUCCESS! Found motionDetailTall for '\(song.attributes.name)':")
                    print("🔗 Video URL: \(videoUrl)")
                    
                    let previewUrl = album.attributes.editorialVideo.motionDetailSquare.previewFrame.url
                    print("🖼 Preview Frame: \(previewUrl)")
                    
                } else {
                    print("⚠️ Could not find editorial video in the response resources.")
                }
            } else {
                print("❌ Could not find song ID for '\(searchTerm)'.")
            }
            
        } catch {
            print("❌ Error during execution: \(error)")
        }
    }
}

// import Foundation
// import iTunesKit

// @main
// struct VerifyCaching {
//     static func main() async {
//         print("🧪 Verifying Token Caching Logic...")
        
//         let client = iTunesWebServiceClient()
//         let catalog = WebCatalogService(client: client)
        
//         do {
//             // First call: Should trigger scraping
//             print("1️⃣ First request...")
//             _ = try await catalog.search(term: "drake")
            
//             // Second call: Should reuse cached token
//             print("\n2️⃣ Second request...")
//             _ = try await catalog.search(term: "taylor swift")
            
//             print("\n✅ Verification complete. Check logs for redundant 'Scraping' messages.")
//         } catch {
//             print("❌ Error: \(error)")
//         }
//     }
// }
