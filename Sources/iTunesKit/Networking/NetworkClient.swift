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
        iTunesDebugLogger.log("iTunesKit: Sending \(method.rawValue) request to \(finalURL.path)")
        
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
        
        var lastError: Error?
        let maxRetries = 2
        
        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = Double(pow(2.0, Double(attempt)))
                iTunesDebugLogger.log("iTunesKit: Retrying \(finalURL.path) in \(delay)s (attempt \(attempt)/\(maxRetries))")
                try? await Task.sleep(for: .seconds(delay))
            }
            
            do {
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    iTunesDebugLogger.log("iTunesKit: Request failed: No HTTP response")
                    throw URLError(.badServerResponse)
                }

                if (200...299).contains(httpResponse.statusCode) {
                    iTunesDebugLogger.log("iTunesKit: Request succeeded (\(data.count) bytes)")
                    return data
                } else {
                    let statusCode = httpResponse.statusCode
                    iTunesDebugLogger.log("iTunesKit: Request failed with status \(statusCode)")
                    
                    if statusCode >= 500 {
                        lastError = URLError(.badServerResponse)
                        continue
                    } else {
                        throw URLError(.badServerResponse)
                    }
                }
            } catch {
                lastError = error
                iTunesDebugLogger.log("iTunesKit: Request encountered error: \(error.localizedDescription)")
                
                let nsError = error as NSError
                let retryableCodes: [Int] = [
                    URLError.timedOut.rawValue,
                    URLError.notConnectedToInternet.rawValue,
                    URLError.networkConnectionLost.rawValue,
                    URLError.cannotConnectToHost.rawValue
                ]
                
                if retryableCodes.contains(nsError.code) {
                    continue
                } else {
                    throw error
                }
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
    
    // Convenience for backward compatibility (optional, but good practice)
    public func get(_ endpoint: String, body: Data? = nil) async throws -> Data {
        try await request(endpoint, method: .get, body: body)
    }
}
