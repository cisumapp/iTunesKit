//
//  NetworkClient.swift
//  SDKit
//
//  Created by Aarav Gupta on 01/01/26.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

public actor NetworkClient {
    
    private let baseURL: String
    private let session: URLSession
    
    // init takes in baseURL
    public init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    // post/send method
    public func send<T: Decodable>(
        _ endpoint: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> T {
        let data = try await request(endpoint, method: method, headers: headers, queryItems: queryItems, body: body)
        let response = try JSONDecoder().decode(T.self, from: data)
        return response
    }
    
    // implement a request method
    public func request(
        _ endpoint: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) async throws -> Data {
        guard var url = URL(string: baseURL) else { throw URLError(.badURL) }
        
        if !endpoint.isEmpty {
            url.appendPathComponent(endpoint)
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        
        guard let finalURL = components?.url else { throw URLError(.badURL) }
        iTunesDebugLogger.log("Sending \(method.rawValue) request to \(finalURL.path)")
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        
        // Default Headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Custom Headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
            if method == .get {
                request.httpMethod = HTTPMethod.post.rawValue
            }
        }
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            iTunesDebugLogger.log("Request failed with status \(statusCode)")
            print("❌ iTunesKit: Network Error (\(statusCode)) for URL: \(request.url?.absoluteString ?? "unknown")")
            if let errorString = String(data: data, encoding: .utf8) {
                print("❌ iTunesKit: Response Body: \(errorString)")
            }
            throw URLError(.badServerResponse)
        }
        
        iTunesDebugLogger.log("Request succeeded (\(data.count) bytes)")
        return data
    }
    
    // Convenience for backward compatibility (optional, but good practice)
    public func get(_ endpoint: String, body: Data? = nil) async throws -> Data {
        try await request(endpoint, method: .get, body: body)
    }
}
