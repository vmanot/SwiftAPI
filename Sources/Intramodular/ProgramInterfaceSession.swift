//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift
import Task

/// A program interface session.
///
/// The combination of a program interface and a compatible request session.
public protocol ProgramInterfaceSession {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    
    var interface: Interface { get }
    var session: Session { get }
}

extension ProgramInterfaceSession {
    public func task<E: Endpoint>(
        for endpointKeypath: KeyPath<Interface, E>
    ) -> ParametrizedTask<E.Input, E.Output, Interface.Error> where E.Root == Interface {
        return .init(body: { (task: ParametrizedTask) in
            guard let input = task.parameter else {
                task.send(.error(.missingInput()))
                
                return .empty()
            }
            
            let endpoint = self.interface[keyPath: endpointKeypath]
            
            do {
                return try self.session.task(with: endpoint.buildRequest(for: self.interface, from: input)).sinkResult({ [weak task] result in
                    switch result {
                        case .success(let value): do {
                            do {
                                task?.send(.success(try endpoint.decodeOutput(from: value)))
                            } catch {
                                task?.send(.error(.invalidOutput()))
                            }
                        }
                        case .failure(let error): do {
                            task?.send(.error(.init(error)))
                        }
                    }
                })
            } catch {
                task.send(.error(.invalidInput()))
                
                return AnyCancellable.empty()
            }
        })
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<Interface, E>,
        with input: E.Input
    ) -> Task<E.Output, Interface.Error> where E.Root == Interface {
        let result = task(for: endpoint)
        
        result.receive(input)
        result.start()
        
        session.cancellables.insert(result)
        
        return result
    }
}

// MARK: - Auxiliary Implementation -

private enum _DefaultProgramInterfaceSessionError: Error {
    case missingInput
    case invalidInput
    case invalidOutput
}

private extension ProgramInterfaceError {
    static func missingInput() -> Self {
        .init(runtimeError: _DefaultProgramInterfaceSessionError.missingInput)
    }
    
    static func invalidInput() -> Self {
        .init(runtimeError: _DefaultProgramInterfaceSessionError.invalidInput)
    }
    
    static func invalidOutput() -> Self {
        .init(runtimeError: _DefaultProgramInterfaceSessionError.invalidOutput)
    }
}
