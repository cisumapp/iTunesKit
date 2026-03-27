import Foundation

public actor CatalogService {
    private let client: NetworkClient
    
    public init(session: URLSession = .shared) {
        self.client = NetworkClient(baseURL: Secrets.baseURL, session: session)
    }
    
    
}
