//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Diagnostics
import Merge
import Swallow

@available(*, deprecated, renamed: "Client")
public typealias Repository = Client

/// A data client.
///
/// The combination of a program interface and a compatible request session.
@dynamicMemberLookup
public protocol Client: Loggable, ObservableObject {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    associatedtype SessionCache: KeyedCache = EmptyKeyedCache<Session.Request, Session.Request.Result> where SessionCache.Key == Session.Request, SessionCache.Value == Session.Request.Response
    associatedtype _ResourceCache: KeyedCodingCache = EmptyKeyedCache<AnyCodingKey, AnyCodable>
    associatedtype LoggerType: LoggerProtocol = PassthroughLogger
        
    var interface: Interface { get }
    var session: Session { get }
    var sessionCache: SessionCache { get }
    
    var _resourceCache: _ResourceCache { get }
}

// MARK: - Implementation -

extension Client where _ResourceCache == EmptyKeyedCache<AnyCodingKey, AnyCodable> {
    public var _resourceCache: _ResourceCache {
        .init()
    }
}

extension Client {
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> _ClientRunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options == Void {
        .init { (input, options) in
            self.run(keyPath, with: input, options: options)
        }
    }
    
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> _ClientRunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options: ExpressibleByNilLiteral {
        .init { (input, options) in
            self.run(self.interface[keyPath: keyPath], with: input, options: options)
        }
    }
    
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> _ClientRunEndpointFunction<Endpoint> where Endpoint.Root == Interface {
        .init { (input, options) in
            self.run(self.interface[keyPath: keyPath], with: input, options: options)
        }
    }
}

extension Client {
    public func run<E: Endpoint>(
        _ endpoint: E,
        with input: E.Input,
        options: E.Options
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface {
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
        _ endpoint: KeyPath<Interface, E>,
        with input: E.Input,
        options: E.Options
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface {
        run(interface[keyPath: endpoint], with: input, options: options)
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<Interface, E>,
        with input: E.Input
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface, E.Options == Void {
        run(interface[keyPath: endpoint], with: input, options: ())
    }
}
