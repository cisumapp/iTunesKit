//
//  iTunesSearchResponse.swift
//  iTunesKit
//
//  Created by Aarav Gupta on 21/03/26.
//

import Foundation

// MARK: - iTunes Search API Models
public struct iTunesSearchResponse: Codable, Sendable {
    public let resultCount: Int
    public let results: [iTunesSearchResult]
}

public struct iTunesSearchResult: Codable, Sendable, Hashable {
    public let wrapperType: String?
    public let kind: String?
    public let artistId: Int?
    public let collectionId: Int?
    public let trackId: Int?
    public let artistName: String?
    public let collectionName: String?
    public let trackName: String?
    public let trackViewUrl: String?
    public let collectionViewUrl: String?
    public let previewUrl: String?
    public let artworkUrl30: String?
    public let artworkUrl60: String?
    public let artworkUrl100: String?
    public let releaseDate: String?
    public let country: String?
    public let currency: String?
    public let trackExplicitness: String?
    public let collectionExplicitness: String?
    public let contentAdvisoryRating: String?
    public let primaryGenreName: String?
}
