import Foundation

public struct iTunesMotionArtworkResolution: Sendable, Equatable {
    public let sourceURL: URL
    public let trackID: Int
    public let collectionID: Int?
    public let catalogAlbumID: String?

    public init(
        sourceURL: URL,
        trackID: Int,
        collectionID: Int?,
        catalogAlbumID: String?
    ) {
        self.sourceURL = sourceURL
        self.trackID = trackID
        self.collectionID = collectionID
        self.catalogAlbumID = catalogAlbumID
    }
}

/// The main entry point for the iTunesKit SDK.
/// Provides a simple interface for searching the legacy iTunes Music Store.
public final class iTunesKit: iTunesClient, @unchecked Sendable {
    
    private let searchService: SearchService
    private let makeWebCatalogService: @Sendable () -> WebCatalogService
    
    public init() {
        self.searchService = SearchService()
        self.makeWebCatalogService = {
            WebCatalogService(client: iTunesWebServiceClient())
        }
    }

    init(
        searchService: SearchService,
        makeWebCatalogService: @escaping @Sendable () -> WebCatalogService
    ) {
        self.searchService = searchService
        self.makeWebCatalogService = makeWebCatalogService
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

    /// Resolves a motion artwork source URL for the best iTunes match of a search term.
    /// - Parameters:
    ///   - term: Search query composed from title/artist metadata.
    ///   - country: Storefront country code.
    /// - Returns: Resolved motion artwork metadata, or `nil` when no match is available.
    public func resolveMotionArtwork(term: String, country: String = "us") async throws -> iTunesMotionArtworkResolution? {
        let searchResponse = try await search(term: term, country: country, media: "music", limit: 1)
        guard let searchMatch = searchResponse.results.first,
              let trackID = searchMatch.trackId else {
            return nil
        }

        let songID = String(trackID)
        let catalogService = makeWebCatalogService()
        let catalogResponse = try await catalogService.fetchSongDetails(songId: songID, storefront: country)
        guard let selection = Self.selectMotionArtwork(
            in: catalogResponse,
            preferredSongID: songID
        ) else {
            return nil
        }

        return iTunesMotionArtworkResolution(
            sourceURL: selection.sourceURL,
            trackID: trackID,
            collectionID: searchMatch.collectionId,
            catalogAlbumID: selection.albumID
        )
    }

    static func selectMotionArtwork(
        in response: iTunesCatalogResponse,
        preferredSongID: String?
    ) -> (sourceURL: URL, albumID: String)? {
        for albumID in preferredAlbumIDs(in: response, preferredSongID: preferredSongID) {
            guard let album = response.resources.albums[albumID],
                  let sourceURL = firstMotionArtworkURL(from: album.attributes.editorialVideo) else {
                continue
            }

            return (sourceURL: sourceURL, albumID: albumID)
        }

        return nil
    }

    private static func preferredAlbumIDs(
        in response: iTunesCatalogResponse,
        preferredSongID: String?
    ) -> [String] {
        var albumIDs: [String] = []

        let fallbackSongID = response.data.first(where: { $0.type == "songs" })?.id
        let targetSongID = preferredSongID ?? fallbackSongID

        if let targetSongID,
           let relationships = response.resources.songs[targetSongID]?.relationships?.albums.data {
            for relationship in relationships {
                let albumID = relationship.id.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !albumID.isEmpty else { continue }
                if !albumIDs.contains(albumID) {
                    albumIDs.append(albumID)
                }
            }
        }

        for albumID in response.resources.albums.keys where !albumIDs.contains(albumID) {
            albumIDs.append(albumID)
        }

        return albumIDs
    }

    private static func firstMotionArtworkURL(from editorialVideo: EditorialVideo) -> URL? {
        let candidates = [
            editorialVideo.motionDetailTall.video,
            editorialVideo.motionTallVideo3X4.video,
            editorialVideo.motionDetailSquare.video,
            editorialVideo.motionSquareVideo1X1.video
        ]

        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            return url
        }

        return nil
    }
}
