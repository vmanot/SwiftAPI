//
// Copyright (c) Vatsal Manot
//

import Dispatch
import Merge
import Swallow
import Task

/// An accessor for a REST resource.
///
/// This type is responsible for getting/setting resource values.
public final class RESTfulResource<
    Value,
    Repository: API.Repository,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: RepositoryResourceProtocol where GetEndpoint.Root == Repository.Interface, SetEndpoint.Root == Repository.Interface {
    public typealias Root = Repository.Interface
    
    @usableFromInline
    let get: EndpointCoordinator<GetEndpoint>
    @usableFromInline
    let getDependencies: [Dependency]
    @usableFromInline
    let set: EndpointCoordinator<SetEndpoint>
    @usableFromInline
    let setDependencies: [Dependency]
    
    @usableFromInline
    weak var _repository: Repository?
    
    public var repository: Repository {
        _repository!
    }
    
    @usableFromInline
    var _lastRootID: Root.ID?
    
    @usableFromInline
    @Published var _wrappedValue: Value?
    
    public var publisher: AnyPublisher<Result<Value, Error>, Never> {
        TODO.here(.fix)
        
        return $_wrappedValue
            .compactMap({ $0 })
            .eraseError()
            .toResultPublisher()
            .eraseToAnyPublisher()
    }
    
    public var latestValue: Value? {
        _wrappedValue
    }
    
    @usableFromInline
    @Published var lastGetTask: AnyTask<GetEndpoint.Output, Root.Error>?
    @usableFromInline
    @Published var lastGetTaskResult: TaskResult<Value, Swift.Error>?
    @usableFromInline
    @Published var lastSetTask: AnyTask<SetEndpoint.Output, Root.Error>?
    @usableFromInline
    @Published var lastSetTaskResult: TaskResult<Void, Swift.Error>?
    
    init(
        get: EndpointCoordinator<GetEndpoint>,
        dependencies getDependencies: [Dependency],
        set: EndpointCoordinator<SetEndpoint>,
        dependencies setDependencies: [Dependency]
    ) {
        self.get = get
        self.getDependencies = getDependencies
        self.set = set
        self.setDependencies = setDependencies
    }
}

extension RESTfulResource {
    private var getDependenciesAreMet: Bool {
        guard let repository = _repository else {
            return false
        }
        
        for dependency in getDependencies {
            if !dependency.isAvailable(in: repository) {
                return false
            }
        }
        
        return true
    }
    
    var needsAutomaticGet: Bool {
        guard let repository = _repository else {
            return false
        }
        
        guard repository.interface.id == _lastRootID else {
            return true
        }
        
        if let lastGetTaskResult = lastGetTaskResult {
            if lastGetTaskResult == .canceled || lastGetTaskResult == .error {
                return false
            }
        }
        
        guard lastGetTask == nil else {
            return false
        }
        
        return _wrappedValue == nil
    }
    
    func receiveGetTaskResult(_ result: TaskResult<GetEndpoint.Output, Root.Error>) {
        do {
            lastGetTask = nil
            lastGetTaskResult = try result
                .map(get.output)
                .mapError({ $0 as Swift.Error })
        } catch {
            lastGetTaskResult = .error(error)
        }
        
        _wrappedValue = lastGetTaskResult?.successValue
    }
}

// MARK: - API -

extension RESTfulResource  {
    public convenience init(
        repository: Repository,
        get: KeyPath<Root, GetEndpoint>,
        _ getValueKeyPath: KeyPath<GetEndpoint.Output, Value>
    ) where GetEndpoint.Input: Initiable, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { _ in .init() },
                output: { $0[keyPath: getValueKeyPath] }
            ),
            dependencies: [],
            set: .init(),
            dependencies: []
        )
        
        self._repository = repository
    }
    
    public convenience init(
        repository: Repository,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input: ExpressibleByNilLiteral, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { _ in .init(nilLiteral: ()) },
                output: { $0 }
            ),
            dependencies: [],
            set: .init(),
            dependencies: []
        )
        
        self._repository = repository
    }
    
    public convenience init(
        repository: Repository,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input: Initiable, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { _ in .init() },
                output: { $0 }
            ),
            dependencies: [],
            set: .init(),
            dependencies: []
        )
        
        self._repository = repository
    }
    
    public convenience init(
        repository: Repository,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input == Void, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { _ in () },
                output: { $0 }
            ),
            dependencies: [],
            set: .init(),
            dependencies: []
        )
        
        self._repository = repository
    }
    
    public convenience init(
        repository: Repository,
        get: KeyPath<Root, GetEndpoint>,
        from getInput: GetEndpoint.Input
    ) where GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { _ in getInput },
                output: { $0 }
            ),
            dependencies: [],
            set: .init(),
            dependencies: []
        )
        
        self._repository = repository
    }
}

// MARK: - Protocol Conformances -

extension RESTfulResource {
    @discardableResult
    public func fetch() -> AnyTask<Value, Error> {
        guard let repository = _repository else {
            assertionFailure()
            
            return .failure(RESTfulResourceError.dependenciesAreNotMet)
        }
        
        guard getDependenciesAreMet else {
            return .failure(RESTfulResourceError.dependenciesAreNotMet)
        }
        
        do {
            lastGetTask?.cancel()
            
            let task = repository.run(
                try get.endpoint(repository),
                with: try get.input(repository),
                options: try get.endpoint(repository).makeDefaultOptions()
            )
            
            self.lastGetTask = task
            
            let resultTask = PassthroughTask<Value, Error>()
            
            task.onResult({ [weak self] result in
                guard let `self` = self else {
                    return
                }
                
                DispatchQueue.asyncOnMainIfNecessary {
                    `self`.receiveGetTaskResult(result)
                    
                    resultTask.send(status: .init(self.lastGetTaskResult!))
                }
            })
            
            return resultTask.eraseToAnyTask()
        } catch {
            lastGetTaskResult = .error(error)
            
            return .failure(error)
        }
    }
}

extension RESTfulResource: Resettable {
    public func reset() {
        _wrappedValue = nil
        
        lastGetTask = nil
        lastGetTaskResult = nil
        lastSetTask = nil
        lastSetTaskResult = nil
    }
}

extension RESTfulResource: Cancellable {
    public func cancel() {
        lastGetTask?.cancel()
        lastSetTask?.cancel()
    }
}

// MARK: - Auxiliary Implementation -

extension RESTfulResource {
    @usableFromInline
    class Dependency {
        func isAvailable(in repository: Repository) -> Bool {
            fatalError()
        }
    }
}

extension RESTfulResource {
    public struct EndpointCoordinator<Endpoint: API.Endpoint> {
        public let endpoint: (Repository) throws -> Endpoint
        public let input: (Repository) throws -> Endpoint.Input
        public let output: (Endpoint.Output) throws -> Value
        
        public init(
            endpoint: @escaping (Repository) throws -> Endpoint,
            input: @escaping (Repository) throws -> Endpoint.Input = { _ in throw Never.Reason.unimplemented },
            output: @escaping (Endpoint.Output) throws -> Value = { _ in throw Never.Reason.unimplemented }
        ) {
            self.endpoint = endpoint
            self.input = input
            self.output = output
        }
        
        public init(
            endpoint: KeyPath<Root, Endpoint>,
            input: @escaping (Repository) throws -> Endpoint.Input = { _ in throw Never.Reason.unimplemented },
            output: @escaping (Endpoint.Output) throws -> Value = { _ in throw Never.Reason.unimplemented }
        ) {
            self.endpoint = { $0.interface[keyPath: endpoint] }
            self.input = input
            self.output = output
        }
    }
}

extension RESTfulResource.EndpointCoordinator where Endpoint == NeverEndpoint<Repository.Interface> {
    public init() {
        self.init(
            endpoint: { _ in throw Never.Reason.irrational },
            input: { _ in throw Never.Reason.irrational },
            output: Never.materialize
        )
    }
}

// MARK: - Auxiliary Implementation -

enum RESTfulResourceError: Error {
    case dependenciesAreNotMet
}
