# iTunesKit 🎵

### The missing Apple Music & iTunes SDK for modern iTunes Storefront Development.

[![](https://img.shields.io/badge/Platform-iOS%20%7C%20macOS-blue.svg)]()
[![](https://img.shields.io/badge/Swift-6.2-orange.svg)]()
[![](https://img.shields.io/badge/SPM-Compatible-green.svg)]()

## 📦 Installation

Add `iTunesKit` to your project via Swift Package Manager.

```swift
dependencies: [
    .package(url: "https://gitlab.com/atpugvaraa/ituneskit.git", from: "1.0.0")
]
```

## 🛠️ Quick Start

### 1. Legacy Search (Safe & Stable)

Access the massive iTunes catalog without the risk of IP bans from developer-facing APIs.

```swift
import iTunesKit

let searchService = SearchService()

func searchDrake() async {
    do {
        // Full support for entity, media, limit, and country
        let results = try await searchService.search(term: "drake nokia", media: "music", limit: 1)
        if let song = results.results.first {
            print("Found: \(song.trackName ?? "") by \(song.artistName ?? "")")
            print("Track ID: \(song.trackId ?? 0)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

### 2. Deep Catalog Metadata (Motion Covers)

Scrape the dynamic web player to fetch editorial video details like `.motionDetailTall`.

```swift
import iTunesKit

let webClient = iTunesWebServiceClient()
let catalogService = WebCatalogService(client: webClient)

func fetchMotionVideo(songId: String) async {
    do {
        let response = try await catalogService.fetchSongDetails(songId: songId)
        if let videoUrl = response.resources.albums.first?.value.editorialVideo?.motionDetailTall?.url {
            print("Motion Video HLS: \(videoUrl)")
        }
    } catch {
        print("Error: \(error)")
    }
}
```

---

## 🤝 Credits & Inspiration

This SDK is built on the shoulders of giants and inspired by the incredible work of Apple Inc. and its engineering teams across the globe. We owe its existence to:

*   **Apple Music & iTunes APIs**: For providing the world's most comprehensive music metadata ecosystem.
*   **MusicKit JS**: The foundation upon which the web player is built, providing the patterns for the reverse-engineered token discovery.
*   **Apple subsidiary engineering**: The teams behind the legacy iTunes Search API that continues to serve as a reliable backbone.

My goal is to provide a polished, Swift-native alternative that focuses on **Developer Experience** while respecting the source.

---

## ⚠️ Disclaimer

**iTunesKit is an unofficial library.** It is not affiliated with, endorsed by, or associated with Apple Inc., iTunes, or Apple Music.

*   This project is for **educational and research purposes only**.
*   It uses reverse-engineered patterns and internal web assets that are subject to change.
*   The SDK includes built-in "Restraint" measures (throttling and rate-limiting) to encourage respectful usage.
*   You are responsible for ensuring your usage complies with Apple's Terms of Service.
*   "Apple", "Apple Music", "iTunes", and "MusicKit" are registered trademarks of Apple Inc.

<!-- sosumi (please don't sue) -->

---

Built with ❤️ & ⚠️ by [Aarav Gupta](https://github.com/atpugvaraa).
