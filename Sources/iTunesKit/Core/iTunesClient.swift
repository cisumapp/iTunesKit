import Foundation

/// Protocol defining the search interface for the iTunesKit SDK.
public protocol iTunesClient {
    /// Searches for songs using the legacy iTunes Search API.
    func searchSongs(term: String) async throws -> [iTunesSearchResult]
    
    /// Low-level search method for custom queries.
    func search(term: String, country: String, media: String, limit: Int) async throws -> iTunesSearchResponse
}