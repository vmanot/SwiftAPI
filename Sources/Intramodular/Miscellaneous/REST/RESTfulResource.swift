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
    Client: API.Client,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: CancellablesHolder, ResourceType where GetEndpoint.Root == Client.Interface, SetEndpoint.Root == Client.Interface {
    typealias EndpointCoordinator<E: Endpoint> = RESTfulResourceEndpointCoordinator<Client, E, Value> where Client.Interface == E.Root
    
    public var configuration: ResourceConfiguration<Value> {
        didSet {
            decacheValueIfNecessary()
        }
    }
    
    private let get: EndpointCoordinator<GetEndpoint>
    private let set: EndpointCoordinator<SetEndpoint>
    
    private var _lastRootID: Client.Interface.ID?
    
    @Published private var _wrappedValue: Value? {
        didSet {
            cacheValueIfNecessary()
        }
    }
    
    @usableFromInline
    weak var _client: Client? {
        didSet {
            get.parent = _client
            set.parent = _client
            
            if oldValue == nil, let client = _client {
                if let clientObjectWillChange = client.objectWillChange as? _opaque_VoidSender {
                    objectWillChange
                        .publish(to: clientObjectWillChange)
                        .subscribe(in: cancellables)
                }
                
                _lastRootID = client.interface.id
                
                client
                    .objectWillChange
                    .receive(on: DispatchQueue.main)
                    .sink { [unowned self, unowned client] _ in
                        if needsGetCall {
                            self.fetch()
                        }
                        
                        self._lastRootID = client.interface.id
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
            .receiveOnMainThread()
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
        guard let client = _client else {
            return false
        }
        
        guard client.interface.id == _lastRootID else {
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
        guard configuration.cachePolicy.returnsCacheData, let cache = _client?._resourceCache, let key = configuration.persistentIdentifier else {
            return
        }
        
        Task(priority: .userInitiated) { @MainActor in
            try await cache.decache(Value.self, forKey: key)
        }
        .publisher(priority: .userInitiated)
        .toResultPublisher()
        .receiveOnMainThread()
        .sink {
            if self._wrappedValue == nil {
                self._wrappedValue = try? $0.get()
            }
        }
        .store(in: cancellables)
    }
    
    private func cacheValueIfNecessary() {
        guard configuration.cachePolicy.returnsCacheData, let cache = _client?._resourceCache, let key = configuration.persistentIdentifier else {
            return
        }
        
        guard let value = latestValue else {
            return
        }
        
        Task { @MainActor in
            try await cache.cache(value, forKey: key)
        }
        .publisher(priority: .utility)
        .subscribe(in: self.cancellables)
    }
    
    private func validateDependencyResolution() throws {
        guard let client = _client else {
            throw RESTfulResourceError.clientResolutionFailed
        }
        
        for dependency in try get.dependencyGraph(client) {
            guard dependency.isAvailable(in: client) else {
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

extension RESTfulResource {
    public func reset() {
        _wrappedValue = nil
        
        get.reset()
        set.reset()
    }
}

// MARK: - Auxiliary -

enum RESTfulResourceError: CustomDebugStringConvertible, Error {
    case clientResolutionFailed
    case dependencyResolutionFailed
    
    var debugDescription: String {
        switch self {
            case .clientResolutionFailed:
                return "Client resolution failed."
            case .dependencyResolutionFailed:
                return "Dependency resolution failed."
        }
    }
}
