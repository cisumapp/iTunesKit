//
//  iTunesCatalogResponse.swift
//  iTunesKit
//
//  Created by Aarav Gupta on 23/03/26.
//

import Foundation

// MARK: - Apple Music Catalog API Models
public struct iTunesCatalogResponse: Codable, Sendable {
    public let data: [iTunesCatalogData]
    public let resources: Resources
}

// MARK: - Data
public struct iTunesCatalogData: Codable, Sendable {
    public let id: String
    public let type: String
    public let href: String
}

// MARK: - Resources
public struct Resources: Codable, Sendable {
    public let albums: [String: Album]
    public let songs: [String: Song]
}

// MARK: - Album
public struct Album: Codable, Sendable {
    public let id: String
    public let type: String
    public let href: String
    public let attributes: AlbumAttributes
}

public struct AlbumAttributes: Codable, Sendable {
    public let editorialVideo: EditorialVideo
}

// MARK: - Song
public struct Song: Codable, Sendable {
    public let id: String
    public let type: String
    public let href: String
    public let attributes: SongAttributes
    public let relationships: SongRelationships?
}

public struct SongAttributes: Codable, Sendable {
    public let hasLyrics: Bool
    public let name: String
    public let url: String
}

public struct SongRelationships: Codable, Sendable {
    public let albums: RelationshipAlbums
}

public struct RelationshipAlbums: Codable, Sendable {
    public let href: String
    public let data: [iTunesCatalogData]
}

public struct EditorialVideo: Codable, Sendable {
    public let motionDetailSquare, motionDetailTall, motionSquareVideo1X1, motionTallVideo3X4: MotionVideo

    enum CodingKeys: String, CodingKey {
        case motionDetailSquare, motionDetailTall
        case motionSquareVideo1X1 = "motionSquareVideo1x1"
        case motionTallVideo3X4 = "motionTallVideo3x4"
    }
}

public struct MotionVideo: Codable, Sendable {
    public let previewFrame: PreviewFrame
    public let video: String
}

public struct PreviewFrame: Codable, Sendable {
    public let bgColor: String
    public let hasP3: Bool
    public let height: Int
    public let textColor1, textColor2, textColor3, textColor4: String
    public let url: String
    public let width: Int
}


// This file was generated from JSON Schema using quicktype, do not modify it directly.
// To parse the JSON, add this file to your project and do:
//
//   let iTunesCatalogResponse = try? JSONDecoder().decode(ITunesCatalogResponse.self, from: jsonData)
