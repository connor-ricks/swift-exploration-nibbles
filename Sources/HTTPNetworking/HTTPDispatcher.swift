import Foundation

// MARK: - HTTPDispatcher

/// A dispatcher that can send requests over the network using a `URLSession`.
public struct HTTPDispatcher {
    
    // MARK: Properties
    
    /// The session that performs the requests.
    let session: URLSession
    
    // MARK: Initializers
    
    /// Creates a dispatcher with the provided session.
    init(session: URLSession) {
        self.session = session
    }
    
    /// Fetches data using the provided request.
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw URLError(.cannotParseResponse)
        }
        
        return (data, response)
    }
}

// MARK: - HTTPDispatcher + Live

extension HTTPDispatcher {
    /// A live implementation of an ``HTTPDispatcher`` that will utilize the provided session to perform requests.
    ///
    /// - Parameter session: The session that powers the dispatcher.
    /// - Returns: An ``HTTPDispatcher``
    public static func live(session: URLSession = .shared) -> HTTPDispatcher {
        HTTPDispatcher(session: session)
    }
}

// MARK: - HTTPDispatcher + Mock

extension HTTPDispatcher {
    /// A mock implementation of an ``HTTPDispatcher`` that will return the provided
    /// response to the corresponding request.
    ///
    /// - Parameter responses: A dictionary of responses keyed by the requests for which they should respond to.
    /// - Returns: An ``HTTPDispatcher``
    public static func mock(
        responses: [URL: MockResponse]
    ) -> HTTPDispatcher {
        MockURLProtocol.mocks.merge(responses, uniquingKeysWith: { $1 })
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return HTTPDispatcher(session: session)
    }
}

// MARK: - HTTPDispatcher + MockResponse

extension HTTPDispatcher {
    /// A mock response can be used to mock interaction with an API.
    public struct MockResponse {
        
        // MARK: Properties
        
        /// The amount of delay that should occur before returning the response.
        let delay: Duration
        
        /// The result of the mock request.
        let result: () -> Result<(Data, HTTPURLResponse), URLError>
        
        /// A closure that should be run in order to introspect the request that was received by the responder.
        let onRecieveRequest: ((URLRequest) -> Void)?
        
        // MARK: Initializers
        
        /// Creates a ``MockResponse`` for the provided configuration.
        public init(
            delay: Duration = .zero,
            result: @escaping () -> Result<(Data, HTTPURLResponse), URLError>,
            onRecieveRequest: ((URLRequest) -> Void)? = nil
        ) {
            self.delay = delay
            self.result = result
            self.onRecieveRequest = onRecieveRequest
        }
        
        /// Creates a ``MockResponse`` for the provided configuration.
        public init(
            delay: Duration = .zero,
            result: Result<(Data, HTTPURLResponse), URLError>,
            onRecieveRequest: ((URLRequest) -> Void)? = nil
        ) {
            self.delay = delay
            self.result = { result }
            self.onRecieveRequest = onRecieveRequest
        }
        
        // MARK: Helpers
        
        /// Creates a successful ``MockResponse`` for the provided configuration.
        public static func success(
            data: Data,
            response: HTTPURLResponse,
            delay: Duration = .zero,
            onRecieveRequest: ((URLRequest) -> Void)? = nil
        ) -> MockResponse {
            .init(delay: delay, result: .success((data, response)), onRecieveRequest: onRecieveRequest)
        }
        
        /// Creates a failed ``MockResponse`` for the provided configuration.
        public static func failure(
            _ error: URLError,
            delay: Duration = .zero,
            onRecieveRequest: ((URLRequest) -> Void)? = nil
        ) -> MockResponse {
            .init(delay: delay, result: .failure(error), onRecieveRequest: onRecieveRequest)
        }
    }
}

// MARK: HTTPDispatcher + MockURLProtocol

extension HTTPDispatcher {
    /// An object that allows mocking an ``HTTPDispatcher``.
    private class MockURLProtocol: URLProtocol {
        
        // MARK: Properties
        
        static var mocks: [URL: MockResponse] = [:]
        
        // MARK: URLProtocol
        
        override class func canInit(with request: URLRequest) -> Bool { true }
        
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        
        override func startLoading() {
            guard let url = request.url, let response = Self.mocks[url] else {
                preconditionFailure("Request dispatched without providing a matching mock.")
            }
            
            response.onRecieveRequest?(request)
            
            Task {
                try? await Task.sleep(for: response.delay)
                
                switch response.result() {
                case .success(let (data, response)):
                    client?.urlProtocol(self, didLoad: data)
                    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                case .failure(let error):
                    client?.urlProtocol(self, didFailWithError: error)
                }
                
                
                client?.urlProtocolDidFinishLoading(self)
            }
        }
        
        override func stopLoading() {}
    }
}
