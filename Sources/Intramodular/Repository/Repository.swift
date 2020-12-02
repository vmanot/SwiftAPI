//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Merge
import Swallow
import Task

/// A data repository.
///
/// The combination of a program interface and a compatible request session.
@dynamicMemberLookup
public protocol Repository: Caching, ObservableObject {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    associatedtype Cache = NoCache<Session.Request, Session.Request.Result> where Cache.Key == Session.Request, Cache.Value == Session.Request.Response
    
    typealias Schema = Interface.Schema
    
    var interface: Interface { get }
    var session: Session { get }
    var cache: Cache { get }
    
    func task<Input, Output, Options>(
        for endpoint: AnyEndpoint<Interface, Input, Output, Options>
    ) -> AnyParametrizedTask<(input: Input, options: Options), Output, Interface.Error>
}

// MARK: - Implementation -

extension Repository {
    public func task<Input, Output, Options>(
        for endpoint: AnyEndpoint<Interface, Input, Output, Options>
    ) -> AnyParametrizedTask<(input: Input, options: Options), Output, Interface.Error> {
        return ParametrizedPassthroughTask(body: { (task: ParametrizedPassthroughTask) in
            guard let (input, options) = task.input else {
                task.send(.error(.missingInput()))
                
                return .empty()
            }
            
            let endpoint = endpoint
            
            do {
                let request = try endpoint.buildRequest(
                    from: input,
                    context: .init(root: self.interface, options: options)
                )
                
                if let response = try? self.cache.decacheValue(forKey: request), let output = try? endpoint.decodeOutput(from: response, context: .init(root: self.interface, input: input, request: request)) {
                    task.send(.success(output))
                    
                    return .empty()
                }
                
                return self
                    .session
                    .task(with: request)
                    .successPublisher
                    .sinkResult({ [weak task] result in
                        switch result {
                            case .success(let value): do {
                                do {
                                    task?.send(.success(try endpoint.decodeOutput(from: value, context: .init(root: self.interface, input: input, request: request))))
                                } catch {
                                    task?.send(.error(.init(runtimeError: error)))
                                }
                            }
                            case .failure(let error): do {
                                task?.send(.error(.init(runtimeError: error)))
                            }
                        }
                    })
            } catch {
                task.send(.error(.init(runtimeError: error)))
                
                return AnyCancellable.empty()
            }
        })
        .eraseToAnyTask()
    }
    
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> RunEndpointFunction<Endpoint> where Endpoint.Root == Interface, Endpoint.Options == Void {
        .init {
            self.run(keyPath, with: $0)
        }
    }
}

// MARK: - Extensions -

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
            return .failure(.init(runtimeError: error))
        }
        
        result.start()
        
        session.cancellables.insert(result)
        
        return result.eraseToAnyTask()
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<Interface, E>,
        with input: E.Input
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface, E.Options == Void {
        run(interface[keyPath: endpoint], with: input, options: ())
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
        .init(runtimeError: _DefaultRepositoryError.missingInput)
    }
    
    static func invalidInput() -> Self {
        .init(runtimeError: _DefaultRepositoryError.invalidInput)
    }
    
    static func invalidOutput() -> Self {
        .init(runtimeError: _DefaultRepositoryError.invalidOutput)
    }
}

public struct RunEndpointFunction<Endpoint: API.Endpoint>  {
    let run: (Endpoint.Input) -> AnyTask<Endpoint.Output, Endpoint.Root.Error>
    
    public func callAsFunction(_ input: (Endpoint.Input)) -> AnyTask<Endpoint.Output, Endpoint.Root.Error> {
        run(input)
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input: ExpressibleByNilLiteral {
        run(nil)
    }
}
