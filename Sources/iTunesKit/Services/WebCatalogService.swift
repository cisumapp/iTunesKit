import Foundation

/// A service for interacting with the Apple Music Catalog Web API.
public actor WebCatalogService {
    
    private let client: iTunesWebServiceClient
    
    public init(client: iTunesWebServiceClient) {
        self.client = client
    }
    
    /// Fetches song details including editorial video information.
    /// - Parameter songId: The Apple Music song ID.
    /// - Returns: An `iTunesCatalogResponse` object.
    public func fetchSongDetails(songId: String, storefront: String = "us") async throws -> iTunesCatalogResponse {
        let endpoint = "catalog/\(storefront)/songs/\(songId)"
        
        let queryItems = [
            URLQueryItem(name: "art[url]", value: "f"),
            URLQueryItem(name: "fields[albums]", value: "editorialVideo"),
            URLQueryItem(name: "fields[songs]", value: "name,url,hasLyrics"),
            URLQueryItem(name: "format[resources]", value: "map"),
            URLQueryItem(name: "include[songs]", value: "albums"),
            URLQueryItem(name: "l", value: "en-US"),
            URLQueryItem(name: "omit[resource]", value: "autos"),
            URLQueryItem(name: "platform", value: "web")
        ]
        
        return try await client.send(endpoint, queryItems: queryItems)
    }
    
    /// Searches for a song using the legacy iTunes Search API (safer).
    /// - Parameters:
    ///   - term: The search term.
    ///   - storefront: The country storefront (e.g., "us").
    /// - Returns: The Apple Music song ID.
    public func search(term: String, storefront: String = "us") async throws -> String? {
        let urlString = "\(Secrets.itunesBaseURL)/search"
        guard var components = URLComponents(string: urlString) else { return nil }
        
        components.queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: storefront),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "limit", value: "1")
        ]
        
        guard let url = components.url else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(iTunesSearchResponse.self, from: data)
        
        if let trackId = response.results.first?.trackId {
            return "\(trackId)"
        }
        
        return nil
    }
}

