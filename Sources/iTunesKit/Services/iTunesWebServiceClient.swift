import Foundation

/// A specialized network client that mimics a "WEB PC Client" and handles token injection.
public actor iTunesWebServiceClient {
    
    private let tokenService: iTunesWebTokenService
    private let session: URLSession
    private let baseURL: String
    
    // SDK Restraint: Minimum time between individual API requests (e.g. 500ms)
    private var lastRequestTime: Date?
    private let minRequestInterval: TimeInterval = 0.5
    
    public init(
        tokenService: iTunesWebTokenService,
        baseURL: String = Secrets.ampBaseURL,
        session: URLSession = .shared
    ) {
        self.tokenService = tokenService
        self.baseURL = baseURL
        self.session = session
    }
    
    /// Sends an authorized request with built-in throttler for "SDk Restraint".
    public func send<T: Decodable>(_ endpoint: String, queryItems: [URLQueryItem] = []) async throws -> T {
        // Enforce a small delay between requests to avoid burst spamming
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minRequestInterval {
                let delay = minRequestInterval - elapsed
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        let token = try await tokenService.fetchToken()
        
        var urlComponents = URLComponents(string: "\(baseURL)/\(endpoint)")
        if !queryItems.isEmpty {
            urlComponents?.queryItems = queryItems
        }
        
        guard let url = urlComponents?.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Mimic WEB PC Client Headers
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(Secrets.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(Secrets.webURL, forHTTPHeaderField: "Origin")
        request.setValue("\(Secrets.webURL)/", forHTTPHeaderField: "Referer")
        
        // Additional Browser-like headers
        request.setValue("*/*", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("same-site", forHTTPHeaderField: "Sec-Fetch-Site")
        
        let (data, response) = try await session.data(for: request)
        self.lastRequestTime = Date()
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            print("❌ iTunesKit Web API Error: \(httpResponse.statusCode) for \(url.absoluteString)")
            if let errorBody = String(data: data, encoding: .utf8) {
                 print("❌ Error Body: \(errorBody)")
            }
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
}
