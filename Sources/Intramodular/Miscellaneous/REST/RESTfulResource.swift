//
// Copyright (c) Vatsal Manot
//

import Combine
import Dispatch
import Merge
import Swallow

/// A REST resource.
///
/// This type is responsible for getting/setting resource values.
public final class RESTfulResource<
    Value,
    Repository: API.Repository,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: CancellablesHolder, ResourceType where GetEndpoint.Root == Repository.Interface, SetEndpoint.Root == Repository.Interface {
    typealias EndpointCoordinator<E: Endpoint> = RESTfulResourceEndpointCoordinator<Repository, E, Value> where Repository.Interface == E.Root
    
    public var configuration: ResourceConfiguration<Value> {
        didSet {
            decacheValueIfNecessary()
        }
    }
    
    private let get: EndpointCoordinator<GetEndpoint>
    private let set: EndpointCoordinator<SetEndpoint>
    
    private var _lastRootID: Repository.Interface.ID?
    
    @Published private var _wrappedValue: Value? {
        didSet {
            cacheValueIfNecessary()
        }
    }
    
    @usableFromInline
    weak var _repository: Repository? {
        didSet {
            get.parent = _repository
            set.parent = _repository
            
            if oldValue == nil, let repository = _repository {
                if let repositoryObjectWillChange = repository.objectWillChange as? _opaque_VoidSender {
                    objectWillChange
                        .receiveOnMainQueue()
                        .publish(to: repositoryObjectWillChange)
                        .subscribe(in: cancellables)
                }
                
                _lastRootID = repository.interface.id
                
                repository
                    .objectWillChange
                    .receive(on: DispatchQueue.main)
                    .sink { [unowned self, unowned repository] _ in
                        if needsGetCall {
                            self.fetch()
                        }
                        
                        self._lastRootID = repository.interface.id
                    }
                    .store(in: cancellables)
            }
        }
    }
    
    public lazy private(set) var publisher: AnyPublisher<Result<Value, Error>, Never> = {
        get.$lastResult
            .compactMap({ $0.flatMap(Result.init(from:)) })
            .shareReplay(1)
            .onSubscribe {
                if self.needsGetCall  {
                    self.fetch()
                }
            }
            .eraseToAnyPublisher()
    }()
    
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
    
    init(
        configuration: ResourceConfiguration<Value>,
        get: EndpointCoordinator<GetEndpoint>,
        set: EndpointCoordinator<SetEndpoint>
    ) {
        self.configuration = configuration
        self.get = get
        self.set = set
        
        _ = publisher
    }
    
    public func unwrap() throws -> Value? {
        latestValue // FIXME!!!
    }
    
    @discardableResult
    public func fetch() -> AnyTask<Value, Error> {
        let getTask = get.run()
        
        getTask
            .successPublisher
            .receiveOnMainQueue()
            .sinkResult(in: cancellables) { result in
                if let value = result.leftValue {
                    self._wrappedValue = value
                } else {
                    if self._wrappedValue != nil {
                        self._wrappedValue = nil
                    }
                }
            }
        
        return getTask
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
        
        // Check if resource fetching was last canceled.
        if let lastGetTaskResult = get.lastResult {
            if lastGetTaskResult == .canceled {
                return false
            }
        }
        
        // Check if the resource is currently being fetched.
        guard get.endpointTask == nil else {
            return false
        }
        
        return get.lastResult == nil
    }
    
    private func decacheValueIfNecessary()  {
        guard configuration.cachePolicy.returnsCacheData, let cache = _repository?.resourceCache, let key = configuration.persistentIdentifier else {
            return
        }
        
        cache
            .decache(Value.self, forKey: key)
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .toResultPublisher()
            .receiveOnMainQueue()
            .sink {
                if self._wrappedValue == nil {
                    self._wrappedValue = try? $0.get()
                }
            }
            .store(in: cancellables)
    }
    
    private func cacheValueIfNecessary() {
        guard configuration.cachePolicy.returnsCacheData, let cache = _repository?.resourceCache, let key = configuration.persistentIdentifier else {
            return
        }
        
        guard let value = latestValue else {
            return
        }
        
        cache
            .cache(value, forKey: key)
            .subscribe(on: DispatchQueue.global(qos: .utility))
            .subscribe(in: self.cancellables)
    }
    
    private func validateDependencyResolution() throws {
        guard let repository = _repository else {
            throw RESTfulResourceError.repositoryResolutionFailed
        }
        
        for dependency in try get.dependencyGraph(repository) {
            guard dependency.isAvailable(in: repository) else {
                throw RESTfulResourceError.dependencyResolutionFailed
            }
        }
    }
}

// MARK: - Conformances -

extension RESTfulResource: Cancellable {
    public func cancel() {
        get.cancel()
        set.cancel()
    }
}

extension RESTfulResource: Resettable {
    public func reset() {
        _wrappedValue = nil
        
        get.reset()
        set.reset()
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
