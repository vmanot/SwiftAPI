//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Diagnostics
import Merge
import Swallow

@available(*, deprecated, renamed: "Client")
public typealias Repository = Client

/// A client for an API specification.
@dynamicMemberLookup
public protocol Client: Logging, ObservableObject {
    associatedtype API: APISpecification
    associatedtype Session: RequestSession where Session.Request == API.Request
    associatedtype SessionCache: KeyedCache = EmptyKeyedCache<Session.Request, Session.Request.Result> where SessionCache.Key == Session.Request, SessionCache.Value == Session.Request.Response
    associatedtype _ResourceCache: KeyedCodingCache = EmptyKeyedCache<AnyCodingKey, AnyCodable>
    associatedtype LoggerType: LoggerProtocol = PassthroughLogger
    
    var interface: API { get }
    var session: Session { get }
    var sessionCache: SessionCache { get }
    
    var _resourceCache: _ResourceCache { get }
}

// MARK: - Implementation

extension Client {
    @available(*, deprecated, renamed: "API")
    public typealias Interface = API
}

extension Client where _ResourceCache == EmptyKeyedCache<AnyCodingKey, AnyCodable> {
    public var _resourceCache: _ResourceCache {
        .init()
    }
}

extension Client {
    public func run<E: Endpoint>(
        _ endpoint: E,
        with input: E.Input,
        options: E.Options
    ) -> AnyTask<E.Output, API.Error> where E.Root == API {
        let task = _ClientEndpointTask(
            client: self,
            endpoint: endpoint,
            input: input,
            options: options,
            cache: .init(sessionCache)
        )
        
        task.start()
        task.store(in: session.cancellables)
        
        return task.eraseToAnyTask()
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<API, E>,
        with input: E.Input,
        options: E.Options
    ) -> AnyTask<E.Output, API.Error> where E.Root == API {
        run(interface[keyPath: endpoint], with: input, options: options)
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<API, E>,
        with input: E.Input,
        options: E.Options
    ) async throws -> E.Output where E.Root == API, E.Options == Void {
        try await run(endpoint, with: input, options: options).value
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<API, E>,
        with input: E.Input
    ) -> AnyTask<E.Output, API.Error> where E.Root == API, E.Options == Void {
        run(interface[keyPath: endpoint], with: input, options: ())
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<API, E>,
        with input: E.Input
    ) async throws -> E.Output where E.Root == API, E.Options == Void {
        try await run(endpoint, with: input).value
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<API, E>
    ) async throws -> E.Output where E.Root == API, E.Input == Void, E.Options == Void {
        try await run(endpoint, with: ()).value
    }
}

// MARK: - Deprecated

extension Client {
    @available(*, deprecated, message: "Use Client.run(_:) instead.")
    public subscript<Endpoint: SwiftAPI.Endpoint>(
        dynamicMember keyPath: KeyPath<API, Endpoint>
    ) -> _ClientRunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options == Void {
        .init { (input, options) in
            self.run(keyPath, with: input, options: options)
        }
    }
    
    @available(*, deprecated, message: "Use Client.run(_:with:options:) instead.")
    public subscript<Endpoint: SwiftAPI.Endpoint>(
        dynamicMember keyPath: KeyPath<API, Endpoint>
    ) -> _ClientRunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options: ExpressibleByNilLiteral {
        .init { (input, options) in
            self.run(self.interface[keyPath: keyPath], with: input, options: options)
        }
    }
    
    @available(*, deprecated, message: "Use Client.run(_:with:options:) instead.")
    public subscript<Endpoint: SwiftAPI.Endpoint>(
        dynamicMember keyPath: KeyPath<API, Endpoint>
    ) -> _ClientRunEndpointFunction<Endpoint> where Endpoint.Root == Interface {
        .init { (input, options) in
            self.run(self.interface[keyPath: keyPath], with: input, options: options)
        }
    }
}
