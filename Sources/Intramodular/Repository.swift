//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow
import Task

/// A data repository.
///
/// The combination of a program interface and a compatible request session.
public protocol Repository: ObservableObject {
    associatedtype Interface: ProgramInterface
    associatedtype Session: RequestSession where Session.Request == Interface.Request
    
    var interface: Interface { get }
    var session: Session { get }
}

extension Repository {
    public func task<E: Endpoint>(
        for endpoint: E
    ) -> ParametrizedTask<E.Input, E.Output, Interface.Error> where E.Root == Interface {
        return .init(body: { (task: ParametrizedTask) in
            guard let input = task.parameter else {
                task.send(.error(.missingInput()))
                
                return .empty()
            }
            
            let endpoint = endpoint
            
            do {
                return try self.session.task(with: endpoint.buildRequest(for: self.interface, from: input)).sinkResult({ [weak task] result in
                    switch result {
                        case .success(let value): do {
                            do {
                                task?.send(.success(try endpoint.decodeOutput(from: value)))
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
    }
    
    public func task<E: Endpoint>(
        for endpointKeypath: KeyPath<Interface, E>
    ) -> ParametrizedTask<E.Input, E.Output, Interface.Error> where E.Root == Interface {
        task(for: interface[keyPath: endpointKeypath])
    }
    
    public func run<E: Endpoint>(
        _ endpoint: E,
        with input: E.Input
    ) -> Task<E.Output, Interface.Error> where E.Root == Interface {
        let result = task(for: endpoint)
        
        result.receive(input)
        result.start()
        
        session.cancellables.insert(result)
        
        return result
    }
    
    public func run<E: Endpoint>(
        _ endpoint: KeyPath<Interface, E>,
        with input: E.Input
    ) -> Task<E.Output, Interface.Error> where E.Root == Interface {
        run(interface[keyPath: endpoint], with: input)
    }
}

// MARK: - Auxiliary Implementation -

open class RepositoryBase<Interface: ProgramInterface, Session: RequestSession>: Repository where Interface.Request == Session.Request {
    @Published public var interface: Interface {
        didSet {
            session.cancellables.cancel()
        }
    }
    
    @Published public var session: Session
    
    public init(interface: Interface, session: Session) {
        self.interface = interface
        self.session = session
    }
    
    public convenience init(interface: Interface) where Session: Initiable {
        self.init(interface: interface, session: .init())
    }
    
    public convenience init(session: Session) where Interface: Initiable {
        self.init(interface: .init(), session: session)
    }
    
    public convenience init() where Interface: Initiable, Session: Initiable {
        self.init(interface: .init(), session: .init())
    }
}

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
