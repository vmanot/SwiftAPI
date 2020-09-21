//
// Copyright (c) Vatsal Manot
//

import Dispatch
import Merge
import Swallow
import Task

/// A protocol for `RESTfulResourceAccessor`.
///
/// This is useful for expressing generic key-paths to resource accessors.
public protocol RESTfulResourceAccessorProtocol {
    associatedtype Value
    associatedtype Container
    associatedtype Root
    associatedtype GetEndpoint: Endpoint where GetEndpoint.Root == Root
    associatedtype SetEndpoint: Endpoint where SetEndpoint.Root == Root
    
    var wrappedValue: Value? { get }
}

/// An accessor for a REST resource.
///
/// This type is responsible for getting/setting resource values and managing their dependencies in a repository.
@propertyWrapper
public final class RESTfulResourceAccessor<
    Value,
    Container: Repository,
    Root,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: RESTfulResourceAccessorProtocol where Container.Interface == Root, GetEndpoint.Root == Root, SetEndpoint.Root == Root {
    @usableFromInline
    let get: EndpointCoordinator<GetEndpoint>
    @usableFromInline
    let getDependencies: [Dependency]
    @usableFromInline
    let set: EndpointCoordinator<SetEndpoint>
    @usableFromInline
    let setDependencies: [Dependency]
    
    @usableFromInline
    weak var _container: Container?
    @usableFromInline
    var _containerSubscription: AnyCancellable?
    @usableFromInline
    var _storageKeyPath: ReferenceWritableKeyPath<Container, RESTfulResourceAccessor>? = nil
    @usableFromInline
    var _lastRootID: Root.ID?
    
    @usableFromInline
    var _wrappedValue: Value?
    
    @usableFromInline
    var lastGetTask: AnyTask<GetEndpoint.Output, Root.Error>?
    @usableFromInline
    var lastGetTaskResult: TaskResult<Value, Swift.Error>?
    @usableFromInline
    var lastSetTask: AnyTask<SetEndpoint.Output, Root.Error>?
    @usableFromInline
    var lastSetTaskResult: TaskResult<Void, Swift.Error>?
    
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
    
    public var wrappedValue: Value? {
        get {
            _wrappedValue
        } set {
            willPublishSignificantChange()
            
            _wrappedValue = newValue
        }
    }
    
    public var projectedValue: RESTfulResourceAccessor {
        self
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
        let isFirstRun = _container == nil
        
        guard let container = object as? Container, let storageKeyPath = storageKeyPath as? ReferenceWritableKeyPath<Container, RESTfulResourceAccessor> else {
            assertionFailure()
            
            return
        }
        
        self._container = container
        self._storageKeyPath = storageKeyPath
        
        if isFirstRun {
            self._lastRootID = container.interface.id
            
            _containerSubscription = container.objectWillChange.receive(on: DispatchQueue.main).sinkResult { [weak self, weak container] _ in
                guard let `self` = self, let container = container else {
                    return
                }
                
                if self.needsAutomaticGet {
                    self.performGetTask()
                }
                
                self._lastRootID = container.interface.id
            }
        }
    }
}

extension RESTfulResourceAccessor {
    func willPublishSignificantChange() {
        guard let container = _container else {
            assertionFailure()
            
            return
        }
        
        (container.objectWillChange as? _opaque_VoidSender)?.send()
    }
}

extension RESTfulResourceAccessor {
    private var getDependenciesAreMet: Bool {
        guard let container = _container else {
            return false
        }
        
        for dependency in getDependencies {
            if !dependency.isAvailable(in: container) {
                return false
            }
        }
        
        return true
    }
    
    private var needsAutomaticGet: Bool {
        guard let container = _container else {
            return false
        }
        
        guard container.interface.id == _lastRootID else {
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
        
        return wrappedValue == nil
    }
    
    func performGetTask() {
        guard let container = _container else {
            assertionFailure()
            
            return
        }
        
        guard getDependenciesAreMet else {
            return
        }
        
        do {
            lastGetTask?.cancel()
            lastGetTask = container.run(try get.endpoint(container), with: try get.input(container))
            lastGetTask?.onResult({ [weak self] result in
                guard let `self` = self else {
                    return
                }
                
                DispatchQueue.asyncOnMainIfNecessary {
                    `self`.receiveGetTaskResult(result)
                }
            })
        } catch {
            lastGetTaskResult = .error(error)
        }
        
        willPublishSignificantChange()
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
        
        willPublishSignificantChange()
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
    
    public convenience init<R0: RESTfulResourceAccessorProtocol>(
        wrappedValue: Value? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from r0: KeyPath<Container, R0>
    ) where GetEndpoint.Input: RESTfulResourceConstructible, GetEndpoint.Input.Resource == R0.Value, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            get: .init(
                endpoint: get,
                input: { container in
                    try .init(from: container[keyPath: r0].wrappedValue.unwrap())
                },
                output: { $0 }
            ),
            dependencies: [ResourceDependency(location: r0)],
            set: .init(),
            dependencies: []
        )
    }
}

// MARK: - Protocol Implementations -

extension RESTfulResourceAccessor {
    public func refresh() {
        performGetTask()
    }
    
    public func fetchIfNecessary() {
        guard wrappedValue == nil else {
            return
        }
        
        refresh()
    }
}

extension RESTfulResourceAccessor: Resettable {
    public func reset() {
        _wrappedValue = nil
        
        lastGetTask = nil
        lastGetTaskResult = nil
        lastSetTask = nil
        lastSetTaskResult = nil
    }
}

extension RESTfulResourceAccessor: Cancellable {
    public func cancel() {
        lastGetTask?.cancel()
        lastSetTask?.cancel()
    }
}

// MARK: - Auxiliary Implementation -

extension RESTfulResourceAccessor {
    @usableFromInline
    class Dependency {
        func isAvailable(in container: Container) -> Bool {
            fatalError()
        }
    }
    
    @usableFromInline
    final class ResourceDependency<R: RESTfulResourceAccessorProtocol>: Dependency {
        let location: KeyPath<Container, R>
        
        init(location: KeyPath<Container, R>) {
            self.location = location
        }
        
        override func isAvailable(in container: Container) -> Bool {
            container[keyPath: location].wrappedValue != nil
        }
    }
}

extension RESTfulResourceAccessor {
    public enum Error: Swift.Error {
        case some
    }
}

extension RESTfulResourceAccessor {
    public struct EndpointCoordinator<Endpoint: API.Endpoint> {
        public let endpoint: (Container) throws -> Endpoint
        public let input: (Container) throws -> Endpoint.Input
        public let output: (Endpoint.Output) throws -> Value
        
        public init(
            endpoint: @escaping (Container) throws -> Endpoint,
            input: @escaping (Container) throws -> Endpoint.Input = { _ in throw Error.some },
            output: @escaping (Endpoint.Output) throws -> Value = { _ in throw Error.some }
        ) {
            self.endpoint = endpoint
            self.input = input
            self.output = output
        }
        
        public init(
            endpoint: KeyPath<Root, Endpoint>,
            input: @escaping (Container) throws -> Endpoint.Input = { _ in throw Error.some },
            output: @escaping (Endpoint.Output) throws -> Value = { _ in throw Error.some }
        ) {
            self.endpoint = { $0.interface[keyPath: endpoint] }
            self.input = input
            self.output = output
        }
    }
}

extension RESTfulResourceAccessor.EndpointCoordinator where Endpoint == NeverEndpoint<Root> {
    public init() {
        self.init(
            endpoint: { _ in throw RESTfulResourceAccessor.Error.some },
            input: { _ in throw RESTfulResourceAccessor.Error.some },
            output: Never.materialize
        )
    }
}

// MARK: - API -

extension Repository where Interface: RESTfulInterface {
    public typealias Resource<Value, GetEndpoint: Endpoint, SetEndpoint: Endpoint> = RESTfulResourceAccessor<Value, Self, Interface, GetEndpoint, SetEndpoint> where GetEndpoint.Root == Interface, SetEndpoint.Root == Interface
}

extension Result {
    public init?<Container, Root, GetEndpoint, SetEndpoint>(
        resource: RESTfulResourceAccessor<Success, Container, Root, GetEndpoint, SetEndpoint>
    ) where Failure == Error {
        switch resource.lastGetTaskResult {
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
