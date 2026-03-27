import Foundation
import iTunesKit

@main
struct FetchNokia {
    static func main() async {
        print("🚀 Starting Apple Music Web API Demo...")
        
        let tokenService = iTunesWebTokenService()
        let webClient = iTunesWebServiceClient(tokenService: tokenService)
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
                    
                    let previewUrl = album.attributes.editorialVideo.motionDetailTall.previewFrame.url
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
