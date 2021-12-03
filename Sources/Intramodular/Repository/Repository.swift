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
public protocol Repository: Caching, ObservableObject {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    associatedtype Cache = NoCache<Session.Request, Session.Request.Result> where Cache.Key == Session.Request, Cache.Value == Session.Request.Response
    associatedtype LoggerType: LoggerProtocol = Logging.Logger
    
    typealias Schema = Interface.Schema
    
    var interface: Interface { get }
    var session: Session { get }
    var cache: Cache { get }
    var logger: LoggerType? { get }
    
    func task<Input, Output, Options>(
        for endpoint: AnyEndpoint<Interface, Input, Output, Options>
    ) -> AnyParametrizedTask<(input: Input, options: Options), Output, Interface.Error>
}

// MARK: - Implementation -

extension Repository where LoggerType == Logging.Logger {
    public var logger: Logger? {
        nil
    }
}

extension Repository {
    public func task<Input, Output, Options>(
        for endpoint: AnyEndpoint<Interface, Input, Output, Options>
    ) -> AnyParametrizedTask<(input: Input, options: Options), Output, Interface.Error> {
        return ParametrizedPassthroughTask(body: { (task: ParametrizedPassthroughTask) in
            guard let (input, options) = task.input else {
                task.send(.error(.missingInput()))
                
                return .empty()
            }
            
            do {
                let request = try endpoint.buildRequest(
                    from: input,
                    context: .init(root: self.interface, options: options)
                )
                
                if let response = try? self.cache.decacheInMemoryValue(forKey: request), let output = try? endpoint.decodeOutput(from: response, context: .init(root: self.interface, input: input, options: options, request: request)) {
                    task.send(.success(output))
                    
                    return .empty()
                }
                
                return self
                    .session
                    .task(with: request)
                    .successPublisher
                    .sinkResult({ [weak task] (result: Result<Interface.Request.Response, Interface.Request.Error>) in
                        switch result {
                            case .success(let value): do {
                                do {
                                    self.logger?.debug(
                                        "Received a request response",
                                        metadata: ["response": value]
                                    )
                                    
                                    let output = try endpoint.decodeOutput(
                                        from: value,
                                        context: .init(
                                            root: self.interface,
                                            input: input,
                                            options: options,
                                            request: request
                                        )
                                    )
                                    
                                    task?.send(.success(output))
                                } catch {
                                    task?.send(.error(.runtime(error)))
                                    
                                    self.logger?.error(
                                        error,
                                        metadata: ["request": request]
                                    )
                                }
                            }
                            case .failure(let error): do {
                                task?.send(.error(.runtime(error)))
                                
                                self.logger?.error(error, metadata: ["request": request])
                            }
                        }
                    })
            } catch {
                task.send(.error(.runtime(error)))
                
                self.logger?.notice("Failed to construct an API request.")
                self.logger?.error(error)
                
                return AnyCancellable.empty()
            }
        })
            .eraseToAnyTask()
    }
    
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
        let result = task(for: .init(endpoint))
        
        do {
            try result.receive((input: input, options: options))
        } catch {
            return .failure(.runtime(error))
        }
        
        result.start()
        
        session.cancellables.insert(result)
        
        return result.eraseToAnyTask()
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

private enum _DefaultRepositoryError: Error {
    case missingInput
    case invalidInput
    case invalidOutput
}

private extension ProgramInterfaceError {
    static func missingInput() -> Self {
        .runtime(_DefaultRepositoryError.missingInput)
    }
    
    static func invalidInput() -> Self {
        .runtime(_DefaultRepositoryError.invalidInput)
    }
    
    static func invalidOutput() -> Self {
        .runtime(_DefaultRepositoryError.invalidOutput)
    }
}

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
