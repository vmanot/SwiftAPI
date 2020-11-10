//
// Copyright (c) Vatsal Manot
//

import Dispatch
import Merge
import Swallow
import Task

/// An accessor for a REST resource.
@propertyWrapper
public final class RESTfulResourceAccessor<
    Value,
    Container: Repository,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: ResourceAccessor where GetEndpoint.Root == Container.Interface, SetEndpoint.Root == Container.Interface {
    public typealias Resource = RESTfulResource<Value, Container, GetEndpoint, SetEndpoint>
    public typealias Root = Container.Interface
    
    fileprivate let cancellables = Cancellables()
    fileprivate let base: Resource
    
    public var projectedValue: AnyRepositoryResource<Container, Value> {
        .init(base, repository: repository)
    }
    
    @usableFromInline
    weak var repository: Container?
    @usableFromInline
    var repositorySubscription: AnyCancellable?
    
    init(
        get: Resource.EndpointCoordinator<GetEndpoint>,
        dependencies getDependencies: [Resource.Dependency],
        set: Resource.EndpointCoordinator<SetEndpoint>,
        dependencies setDependencies: [Resource.Dependency]
    ) {
        self.base = .init(
            get: get,
            dependencies: getDependencies,
            set: set,
            dependencies: setDependencies
        )
    }
    
    public var wrappedValue: Value? {
        get {
            base._wrappedValue
        } set {
            base._wrappedValue = newValue
        }
    }
    
    @inlinable
    public static subscript<EnclosingSelf: Repository>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value?>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, RESTfulResourceAccessor>
    ) -> Value? where EnclosingSelf.Interface == Root {
        get {
            object[keyPath: storageKeyPath].receiveEnclosingInstance(object, storageKeyPath: storageKeyPath)
            
            return object[keyPath: storageKeyPath].wrappedValue
        } set {
            object[keyPath: storageKeyPath].receiveEnclosingInstance(object, storageKeyPath: storageKeyPath)
            
            object[keyPath: storageKeyPath].wrappedValue = newValue
        }
    }
    
    @usableFromInline
    func receiveEnclosingInstance<EnclosingSelf: Repository>(
        _ object:  EnclosingSelf,
        storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, RESTfulResourceAccessor>
    ) where EnclosingSelf.Interface == Root {
        let isFirstRun = repository == nil
        
        guard let repository = object as? Container else {
            assertionFailure()
            
            return
        }
        
        self.repository = repository
        self.base._repository = repository
        
        if isFirstRun {
            if let repositoryObjectWillChange = repository.objectWillChange as? _opaque_VoidSender {
                self.base.objectWillChange
                    .receiveOnMainQueue()
                    .publish(to: repositoryObjectWillChange)
                    .store(in: cancellables)
            }
            
            self.base._lastRootID = repository.interface.id
            
            repositorySubscription = repository.objectWillChange.receive(on: DispatchQueue.main).sinkResult { [weak self, weak repository] _ in
                guard let self = self, let repository = repository else {
                    return
                }
                
                if self.base.needsAutomaticGet {
                    self.base.performGetTask()
                }
                
                self.base._lastRootID = repository.interface.id
            }
        }
    }
}

// MARK: - Initialization -

extension RESTfulResourceAccessor  {
    public convenience init(
        wrappedValue: Value? = nil,
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
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
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
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
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
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
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
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
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
    }
    
    public convenience init<R0: ResourceAccessor>(
        wrappedValue: Value? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from r0: KeyPath<Container, R0>
    ) where GetEndpoint.Input: RESTfulResourceValueConstructible, GetEndpoint.Input.ResourceValue == R0.Value, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { repository in
                    try .init(from: repository[keyPath: r0].wrappedValue.unwrap())
                },
                output: { $0 }
            ),
            dependencies: [ResourceDependency(location: r0)],
            set: .init(),
            dependencies: []
        )
    }
}

// MARK: - Auxiliary Implementation -

extension RESTfulResourceAccessor {
    @usableFromInline
    final class ResourceDependency<R: ResourceAccessor>: Resource.Dependency {
        let location: KeyPath<Container, R>
        
        init(location: KeyPath<Container, R>) {
            self.location = location
        }
        
        override func isAvailable(in repository: Container) -> Bool {
            repository[keyPath: location].wrappedValue != nil
        }
    }
}

// MARK: - API -

extension Repository where Interface: RESTfulInterface {
    public typealias Resource<Value, GetEndpoint: Endpoint, SetEndpoint: Endpoint> = RESTfulResourceAccessor<Value, Self, GetEndpoint, SetEndpoint> where GetEndpoint.Root == Interface, SetEndpoint.Root == Interface
}

extension Result {
    public init?<Repository, GetEndpoint, SetEndpoint>(
        resource: RESTfulResourceAccessor<Success, Repository, GetEndpoint, SetEndpoint>
    ) where Failure == Error {
        switch resource.base.lastGetTaskResult {
            case .none:
                return nil
            case .some(let result): do {
                switch result {
                    case .canceled:
                        return nil
                    case .success(let value):
                        self = .success(value)
                    case .error(let error):
                        self = .failure(error)
                }
            }
            
        }
    }
}
