//
// Copyright (c) Vatsal Manot
//

import Dispatch
import Merge
import Swallow

/// An accessor for a REST resource.
///
/// This type is responsible for getting/setting resource values.
public final class RESTfulResource<
    Value,
    Repository: API.Repository,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: CancellablesHolder, RepositoryResourceType where GetEndpoint.Root == Repository.Interface, SetEndpoint.Root == Repository.Interface {
    public typealias Root = Repository.Interface
    
    fileprivate let get: EndpointCoordinator<GetEndpoint>
    fileprivate let dependenciesForGet: [EndpointDependency]
    fileprivate let set: EndpointCoordinator<SetEndpoint>
    fileprivate let dependenciesForSet: [EndpointDependency]
    
    var _lastRootID: Root.ID?
    
    @Published fileprivate var _wrappedValue: Value?
    @Published fileprivate var lastGetTask: AnyTask<GetEndpoint.Output, Root.Error>?
    @Published fileprivate var lastGetTaskResult: TaskResult<Value, Swift.Error>?
    @Published fileprivate var lastSetTask: AnyTask<SetEndpoint.Output, Root.Error>?
    @Published fileprivate var lastSetTaskResult: TaskResult<Void, Swift.Error>?
    
    @usableFromInline
    weak var _repository: Repository?
    
    public var repository: Repository {
        guard let repository = _repository else {
            fatalError("Could not resolve a repository for this resource.")
        }
        
        return repository
    }
    
    public var publisher: AnyPublisher<Result<Value, Error>, Never> {
        $lastGetTaskResult
            .compactMap({ $0 })
            .compactMap({ Result(from: $0) })
            .eraseToAnyPublisher()
    }
    
    public var latestValue: Value? {
        get {
            _wrappedValue
        } set{
            _wrappedValue = newValue // FIXME!!!
        }
    }
    
    public var projectedValue: AnyResource<Value> {
        .init(self)
    }
    
    public func unwrap() throws -> Value? {
        latestValue // FIXME!!!
    }
    
    init(
        get: EndpointCoordinator<GetEndpoint>,
        dependenciesForGet: [EndpointDependency],
        set: EndpointCoordinator<SetEndpoint>,
        dependenciesForSet: [EndpointDependency]
    ) {
        self.get = get
        self.dependenciesForGet = dependenciesForGet
        self.set = set
        self.dependenciesForSet = dependenciesForSet
    }
}

extension RESTfulResource {
    var needsGetCall: Bool {
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
    
    func receiveGetEndpointOutput(
        _ output: TaskResult<GetEndpoint.Output, Root.Error>
    ) -> TaskResult<Value, Error> {
        var result: TaskResult<Value, Error>
        
        lastGetTask = nil
        
        do {
            result = try output
                .map(get.output)
                .mapError({ $0 as Swift.Error })
            
            if var _result = try? self.lastGetTaskResult?.get() as? _opaque_PaginatedListType, let newResult = try? result.get() as? _opaque_PaginatedListType {
                try _result._opaque_concatenateInPlace(with: newResult)
                
                result = .success(try cast(_result, to: Value.self))
            }
        } catch {
            result = .error(error)
        }
            
        self.lastGetTaskResult = result
        
        _wrappedValue = result.successValue

        return result
    }
}

// MARK: - Initializers -

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
            dependenciesForGet: [],
            set: .init(),
            dependenciesForSet: []
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
            dependenciesForGet: [],
            set: .init(),
            dependenciesForSet: []
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
            dependenciesForGet: [],
            set: .init(),
            dependenciesForSet: []
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
            dependenciesForGet: [],
            set: .init(),
            dependenciesForSet: []
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
            dependenciesForGet: [],
            set: .init(),
            dependenciesForSet: []
        )
        
        self._repository = repository
    }
}

// MARK: - Conformances -

extension RESTfulResource {
    @discardableResult
    public func fetch() -> AnyTask<Value, Error> {
        do {
            try validateDependencyResolution()
            
            let task = try createTaskForGetEndpoint()
            let resultTask = PassthroughTask<Value, Error>()
            
            task.resultPublisher
                .receiveOnMainQueue()
                .sink(in: cancellables) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    
                    resultTask.send(status: .init(self.receiveGetEndpointOutput(result)))
                }
            
            return resultTask.eraseToAnyTask()
        } catch {
            return .failure(error)
        }
    }
    
    private func createTaskForGetEndpoint() throws ->  AnyTask<GetEndpoint.Output, Repository.Interface.Error> {
        do {
            lastGetTask?.cancel()
            
            let getEndpoint = try get.endpoint(repository)
            var getEndpointOptions = try getEndpoint.makeDefaultOptions()
            
            if let latestValue = latestValue as? _opaque_PaginatedListType {
                if var _getEndpointOptions = getEndpointOptions as? SpecifiesPaginationCursor {
                    _getEndpointOptions.paginationCursor = latestValue.nextCursor
                    
                    getEndpointOptions = try cast(_getEndpointOptions)
                }
            }
            
            let task = repository.run(
                try get.endpoint(repository),
                with: try get.input(repository),
                options: getEndpointOptions
            )
            
            self.lastGetTask = task
            
            return task
        } catch {
            lastGetTaskResult = .error(error)
            
            throw error
        }
    }
    
    private func validateDependencyResolution() throws {
        guard let repository = _repository else {
            throw RESTfulResourceError.repositoryResolutionFailed
        }
        
        for dependency in dependenciesForGet {
            guard dependency.isAvailable(in: repository) else {
                throw RESTfulResourceError.dependencyResolutionFailed
            }
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
    class EndpointDependency {
        func isAvailable(in repository: Repository) -> Bool {
            fatalError()
        }
    }
    
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
        
        public init() where Endpoint == NeverEndpoint<Repository.Interface> {
            self.init(
                endpoint: { _ in throw Never.Reason.irrational },
                input: { _ in throw Never.Reason.irrational },
                output: Never.materialize
            )
        }
    }
}

// MARK: - Auxiliary Implementation -

enum RESTfulResourceError: CustomDebugStringConvertible, Error {
    case repositoryResolutionFailed
    case dependencyResolutionFailed
    
    var debugDescription: String {
        switch self {
            case .repositoryResolutionFailed:
                return "Repository resolution failed."
            case .dependencyResolutionFailed:
                return "Dependency resolution failed."
        }
    }
}
