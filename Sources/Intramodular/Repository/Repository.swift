//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow
import Task

/// A data repository.
///
/// The combination of a program interface and a compatible request session.
@dynamicMemberLookup
public protocol Repository: ObservableObject {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    
    typealias Schema = Interface.Schema
    
    var interface: Interface { get }
    var session: Session { get }
}

// MARK: - Implementation -

extension Repository {
    public subscript<Endpoint: API.Endpoint>(
        dynamicMember keyPath: KeyPath<Interface, Endpoint>
    ) -> RunEndpointFunction<Endpoint> where Endpoint.Root == Interface {
        .init {
            self.run(keyPath, with: $0)
        }
    }
}

// MARK: - Extensions -

extension Repository {
    public func task<E: Endpoint>(
        for endpoint: E
    ) -> AnyParametrizedTask<E.Input, E.Output, Interface.Error> where E.Root == Interface {
        return ParametrizedPassthroughTask(body: { (task: ParametrizedPassthroughTask) in
            guard let input = task.input else {
                task.send(.error(.missingInput()))
                
                return .empty()
            }
            
            let endpoint = endpoint
            
            do {
                let request = try endpoint.buildRequest(
                    from: input,
                    context: .init(root: self.interface)
                )
                
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
    
    public func task<E: Endpoint>(
        for endpoint: KeyPath<Interface, E>
    ) -> AnyParametrizedTask<E.Input, E.Output, Interface.Error> where E.Root == Interface {
        task(for: interface[keyPath: endpoint])
    }
    
    public func run<E: Endpoint>(
        _ endpoint: E,
        with input: E.Input
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface {
        let result = task(for: endpoint)
        
        do {
            try result.receive(input)
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
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface {
        run(interface[keyPath: endpoint], with: input)
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<Interface.Endpoints.Type, E>,
        with input: E.Input
    ) -> AnyTask<E.Output, Interface.Error> where E.Root == Interface {
        run(Interface.Endpoints.self[keyPath: endpoint], with: input)
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
    
    public func callAsFunction(_ input: (Endpoint.Input)) -> some Task {
        run(input)
    }
}
