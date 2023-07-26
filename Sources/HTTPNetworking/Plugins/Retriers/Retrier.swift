import Foundation

public typealias RetryHandler = (URLRequest, URLSession, Error) async -> RetryStrategy

/// An ``HTTPRequestRetrier`` that can be used to retry an ``HTTPRequest`` upon failure.
public struct Retrier: HTTPRequestRetrier {
    
    // MARK: Properties
    
    private let handler: RetryHandler
    
    // MARK: Initializers
    
    
    /// Creates a ``Retrier`` from the provided handler.
    ///
    /// - Parameter handler: The handler to execute when the ``Retrier`` is asked if it should retry.
    public init(_ handler: @escaping RetryHandler) {
        self.handler = handler
    }
    
    // MARK: ResponseValidator
    
    public func retry(_ request: URLRequest, for session: URLSession, dueTo error: Error) async -> RetryStrategy {
        await handler(request, session, error)
    }
}

// MARK: - HTTPRequest + Retrier

extension HTTPRequest {
    /// Applies a ``Retrier`` that handles retry logic using the provided ``RetryHandler``.
    @discardableResult
    public func retry(_ handler: @escaping RetryHandler) -> Self {
        retry(with: Retrier(handler))
    }
}
