//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Diagnostics
import Merge
import Swallow

/// A data repository.
///
/// The combination of a program interface and a compatible request session.
@dynamicMemberLookup
public protocol Repository: ObservableObject {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    associatedtype SessionCache: KeyedCache = EmptyKeyedCache<Session.Request, Session.Request.Result> where SessionCache.Key == Session.Request, SessionCache.Value == Session.Request.Response
    associatedtype ResourceCache: KeyedCodingCache = EmptyKeyedCache<AnyCodingKey, AnyCodable>
    associatedtype LoggerType: LoggerProtocol = Logging.Logger
    
    typealias Schema = Interface.Schema
    
    var logger: LoggerType? { get }
    var interface: Interface { get }
    var session: Session { get }
    var sessionCache: SessionCache { get }
    var resourceCache: ResourceCache { get }
}

// MARK: - Implementation -

extension Repository where LoggerType == Logging.Logger {
    public var logger: Logger? {
        nil
    }
}

extension Repository where ResourceCache == EmptyKeyedCache<AnyCodingKey, AnyCodable> {
    public var resourceCache: ResourceCache {
        .init()
    }
}

extension Repository {
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> RunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options == Void {
        .init { (input, options) in
            self.run(keyPath, with: input, options: options)
        }
    }
    
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> RunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options: ExpressibleByNilLiteral {
        .init { (input, options) in
            self.run(self.interface[keyPath: keyPath], with: input, options: options)
        }
    }
    
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> RunEndpointFunction<Endpoint> where Endpoint.Root == Interface {
        .init { (input, options) in
            self.run(self.interface[keyPath: keyPath], with: input, options: options)
        }
    }
}

extension Repository {
    public func run<E: Endpoint>(
        _ endpoint: E,
        with input: E.Input,
        options: E.Options
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface {
        let task = RepositoryRunEndpointTask(
            repository: self,
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
}

// MARK: - Auxiliary Implementation -

public struct RunEndpointFunction<Endpoint: API.Endpoint>  {
    let run: (Endpoint.Input, Endpoint.Options) -> AnyTask<Endpoint.Output, Endpoint.Root.Error>
    
    public func callAsFunction(_ input: (Endpoint.Input), options: Endpoint.Options) -> AnyTask<Endpoint.Output, Endpoint.Root.Error> {
        run(input, options)
    }
    
    public func callAsFunction(_ input: (Endpoint.Input)) -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Options == Void {
        run(input, ())
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input: ExpressibleByNilLiteral, Endpoint.Options == Void {
        run(nil, ())
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input: ExpressibleByNilLiteral, Endpoint.Options: ExpressibleByNilLiteral {
        run(nil, nil)
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input == Void, Endpoint.Options == Void {
        run((), ())
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input == Void, Endpoint.Options: ExpressibleByNilLiteral {
        run((), nil)
    }
}
