import Foundation

/// The main entry point for the iTunesKit SDK.
/// Provides a simple interface for searching the legacy iTunes Music Store.
public final class iTunesKit: iTunesClient, @unchecked Sendable {
    
    private let searchService: SearchService
    
    public init() {
        self.searchService = SearchService()
    }
    
    /// Searches for songs using the legacy iTunes Search API.
    /// - Parameter term: The search term (e.g., artist name, song title).
    /// - Returns: A list of search results.
    public func searchSongs(term: String) async throws -> [iTunesSearchResult] {
        let response = try await search(term: term, country: "us", media: "music", limit: 50)
        return response.results
    }
    
    /// Low-level search method for custom queries.
    public func search(term: String, country: String, media: String, limit: Int) async throws -> iTunesSearchResponse {
        try await searchService.search(term: term, country: country, media: media, limit: limit)
    }
}
