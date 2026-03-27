import Foundation

/// A service that scrapes the Apple Music web player to obtain a developer token.
public actor iTunesWebTokenService {
    
    private let session: URLSession
    private var cachedToken: String?
    private var tokenExpiry: Date?
    private var lastScrapeDate: Date?
    
    // Minimum time between scrapes to avoid spamming Apple's servers
    private let minScrapeInterval: TimeInterval = 3600 // 1 hour
    
    public init(session: URLSession = .shared) {
        self.session = session
    }
    
    /// Fetches a valid developer token by scraping the Apple Music application script.
    public func fetchToken() async throws -> String {
        // 1. Return cached token if still valid
        if let token = cachedToken, let expiry = tokenExpiry, expiry > Date() {
            return token
        }
        
        // 2. Check if we scraped too recently
        if let lastScrape = lastScrapeDate, Date().timeIntervalSince(lastScrape) < minScrapeInterval {
            print("⚠️ iTunesKit: Rate limiting scrape. Using last known token (or failing if none).")
            if let token = cachedToken { return token }
            throw URLError(.cannotConnectToHost) // Or a custom rate limit error
        }
        
        print("🔍 iTunesKit: Scraping Apple Music Web Player...")
        
        guard let url = URL(string: Secrets.webNewURL) else {
            throw URLError(.badURL)
        }
        
        // Mark scrape attempt
        self.lastScrapeDate = Date()
        
        // Fetch the bootstrap HTML to find the latest application script
        var request = URLRequest(url: url)
        request.setValue(Secrets.userAgent, forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
             throw URLError(.cannotDecodeRawData)
        }
        
        // Find the main application JS file (e.g., /assets/index~[hash].js)
        let jsPattern = "/assets/index~[a-zA-Z0-9]+\\.js"
        guard let jsRange = html.range(of: jsPattern, options: .regularExpression) else {
            print("❌ iTunesKit: Could not find application script URL in HTML")
            throw URLError(.cannotParseResponse)
        }
        
        let jsPath = String(html[jsRange])
        let jsURLString = "\(Secrets.webURL)\(jsPath)"
        print("🚀 iTunesKit: Fetching application script: \(jsURLString)")
        
        guard let jsURL = URL(string: jsURLString) else {
            throw URLError(.badURL)
        }
        
        var jsRequest = URLRequest(url: jsURL)
        jsRequest.setValue(Secrets.userAgent, forHTTPHeaderField: "User-Agent")
        
        let (jsData, _) = try await session.data(for: jsRequest)
        guard let jsContent = String(data: jsData, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        if let token = findToken(in: jsContent) {
            // Success! Cache the token for 2 hours (typical Apple Music token lifespan is longer, but 2h is safe)
            self.cachedToken = token
            self.tokenExpiry = Date().addingTimeInterval(7200) 
            print("✅ iTunesKit: Successfully obtained devToken from script")
            return token
        }

        print("❌ iTunesKit: Failed to find devToken in application script")
        throw URLError(.cannotParseResponse)
    }
    
    private func findToken(in text: String) -> String? {
        let pattern = "eyJ[a-zA-Z0-9._-]{200,}" 
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range)
        
        for match in matches {
            if let tokenRange = Range(match.range, in: text) {
                let token = String(text[tokenRange])
                let dotCount = token.filter { $0 == "." }.count
                if dotCount >= 2 {
                    return token
                }
            }
        }
        return nil
    }
}
