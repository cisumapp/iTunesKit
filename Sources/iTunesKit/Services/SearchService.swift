import Foundation

public actor SearchService {
    private let client: NetworkClient
    
    public init(session: URLSession = .shared) {
        self.client = NetworkClient(baseURL: Secrets.itunesBaseURL, session: session)
    }
    
    /// Searches the iTunes Store for content.
    /// - Parameters:
    ///   - term: The URL-encoded text string you want to search for.
    ///   - country: The two-letter country code for the store you want to search. Default is "us".
    ///   - media: The media type you want to search for (e.g., "music", "movie").
    ///   - entity: The type of results you want returned, relative to the specified media type.
    ///   - attribute: The attribute you want to search for in the specified entity.
    ///   - limit: The number of search results you want the iTunes Store to return. Default is 50.
    ///   - lang: The language you want to use when returning search results (e.g., "en_us", "ja_jp").
    ///   - version: The search result key version. Default is 2.
    ///   - explicit: A flag indicating whether or not you want to include explicit content. Default is true.
    /// - Returns: An `iTunesSearchResponse` object.
    public func search(
        term: String,
        country: String = "us",
        media: String? = nil,
        entity: String? = nil,
        attribute: String? = nil,
        limit: Int = 50,
        lang: String = "en_us",
        version: Int = 2,
        explicit: Bool = true
    ) async throws -> iTunesSearchResponse {
        var queryItems = [
            URLQueryItem(name: "term", value: term),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "lang", value: lang),
            URLQueryItem(name: "version", value: "\(version)"),
            URLQueryItem(name: "explicit", value: explicit ? "Yes" : "No")
        ]
        
        if let media = media {
            queryItems.append(URLQueryItem(name: "media", value: media))
        }
        if let entity = entity {
            queryItems.append(URLQueryItem(name: "entity", value: entity))
        }
        if let attribute = attribute {
            queryItems.append(URLQueryItem(name: "attribute", value: attribute))
        }
        
        return try await client.send("search", queryItems: queryItems)
    }
    
    /// Looks up content by ID (e.g., iTunes ID, AMG ID, UPC, ISBN).
    /// - Parameters:
    ///   - id: The id you want to look up (e.g., 909253).
    ///   - entity: The type of results you want returned.
    ///   - limit: The number of search results you want the iTunes Store to return. Default is 50.
    ///   - sort: The sort order.
    /// - Returns: An `iTunesSearchResponse` object.
    public func lookup(
        id: String? = nil,
        amgArtistId: String? = nil,
        amgAlbumId: String? = nil,
        amgVideoId: String? = nil,
        upc: String? = nil,
        isbn: String? = nil,
        entity: String? = nil,
        limit: Int? = nil,
        sort: String? = nil
    ) async throws -> iTunesSearchResponse {
        var queryItems = [URLQueryItem]()
        
        if let id = id { queryItems.append(URLQueryItem(name: "id", value: id)) }
        if let id = amgArtistId { queryItems.append(URLQueryItem(name: "amgArtistId", value: id)) }
        if let id = amgAlbumId { queryItems.append(URLQueryItem(name: "amgAlbumId", value: id)) }
        if let id = amgVideoId { queryItems.append(URLQueryItem(name: "amgVideoId", value: id)) }
        if let id = upc { queryItems.append(URLQueryItem(name: "upc", value: id)) }
        if let id = isbn { queryItems.append(URLQueryItem(name: "isbn", value: id)) }
        if let entity = entity { queryItems.append(URLQueryItem(name: "entity", value: entity)) }
        if let limit = limit { queryItems.append(URLQueryItem(name: "limit", value: "\(limit)")) }
        if let sort = sort { queryItems.append(URLQueryItem(name: "sort", value: sort)) }
        
        return try await client.send("lookup", queryItems: queryItems)
    }
}
