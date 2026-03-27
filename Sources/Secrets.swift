//
//  Secrets.swift
//  iTunesKit
//
//  Created by Aarav Gupta on 21/03/26.
//

import Foundation

/// Internal constants and configuration for the iTunesKit SDK.
public struct Secrets {
    public static let baseURL = "https://amp-api.music.apple.com/v1/catalog"
    public static let ampBaseURL = "https://amp-api.music.apple.com/v1"
    public static let webURL = "https://music.apple.com"
    public static let webNewURL = "https://music.apple.com/us/new"
    public static let itunesBaseURL = "https://itunes.apple.com"

    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
    
    public static let defaultLanguage = "en-US"
    public static let defaultStorefront = "us"
}
