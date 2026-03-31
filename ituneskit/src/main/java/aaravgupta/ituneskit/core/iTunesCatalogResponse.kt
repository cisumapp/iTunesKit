package aaravgupta.ituneskit

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
public data class iTunesCatalogResponse(
    val data: List<iTunesCatalogData>,
    val resources: Resources
)

@Serializable
public data class iTunesCatalogData(
    val id: String,
    val type: String,
    val href: String
)

@Serializable
public data class Resources(
    val albums: Map<String, Album>,
    val songs: Map<String, Song>
)

@Serializable
public data class Album(
    val id: String,
    val type: String,
    val href: String,
    val attributes: AlbumAttributes
)

@Serializable
public data class AlbumAttributes(
    val editorialVideo: EditorialVideo
)

@Serializable
public data class Song(
    val id: String,
    val type: String,
    val href: String,
    val attributes: SongAttributes,
    val relationships: SongRelationships? = null
)

@Serializable
public data class SongAttributes(
    val hasLyrics: Boolean,
    val name: String,
    val url: String
)

@Serializable
public data class SongRelationships(
    val albums: RelationshipAlbums
)

@Serializable
public data class RelationshipAlbums(
    val href: String,
    val data: List<iTunesCatalogData>
)

@Serializable
public data class EditorialVideo(
    val motionDetailSquare: MotionVideo,
    val motionDetailTall: MotionVideo,
    @SerialName("motionSquareVideo1x1")
    val motionSquareVideo1X1: MotionVideo,
    @SerialName("motionTallVideo3x4")
    val motionTallVideo3X4: MotionVideo
)

@Serializable
public data class MotionVideo(
    val previewFrame: PreviewFrame,
    val video: String
)

@Serializable
public data class PreviewFrame(
    val bgColor: String,
    val hasP3: Boolean,
    val height: Int,
    val textColor1: String,
    val textColor2: String,
    val textColor3: String,
    val textColor4: String,
    val url: String,
    val width: Int
)