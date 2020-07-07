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
public struct RESTfulResourceAccessor<
    Value,
    Container: Repository,
    Root,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: RESTfulResourceAccessorProtocol where Container.Interface == Root, GetEndpoint.Root == Root, SetEndpoint.Root == Root {
    @usableFromInline
    var _wrappedValue: Value?
    
    @usableFromInline
    let get: EndpointConstructor<GetEndpoint>?
    @usableFromInline
    let set: EndpointConstructor<SetEndpoint>?
    
    @usableFromInline
    weak var _container: Container?
    @usableFromInline
    var _containerSubscription: AnyCancellable?
    @usableFromInline
    var _storageKeyPath: ReferenceWritableKeyPath<Container, Self>?
    @usableFromInline
    var _lastRootID: Root.ID?
    
    @usableFromInline
    var lastGetTask: Task<GetEndpoint.Output, Root.Error>?
    @usableFromInline
    var lastGetTaskResult: TaskResult<Value, Swift.Error>?
    @usableFromInline
    var lastSetTask: Task<SetEndpoint.Output, Root.Error>?
    @usableFromInline
    var lastSetTaskResult: TaskResult<Void, Swift.Error>?
    
    public var wrappedValue: Value? {
        get {
            _wrappedValue
        } set {
            notifyContainer()
            
            _wrappedValue = newValue
        }
    }
    
    var requiresGet: Bool {
        if let container = _container {
            if container.interface.id != _lastRootID {
                return true
            }
        }
        
        if let lastGetTaskResult = lastGetTaskResult {
            if lastGetTaskResult == .canceled || lastGetTaskResult == .error {
                return false
            }
        }
        
        if let lastGetTask = lastGetTask {
            if lastGetTask.isActive {
                return false
            }
        }
        
        return wrappedValue == nil
    }
    
    public var projectedValue: Self {
        self
    }
    
    @inlinable
    public static subscript<EnclosingSelf: Repository>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value?>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
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
    mutating func receiveEnclosingInstance<EnclosingSelf: Repository>(
        _ object:  EnclosingSelf,
        storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) where EnclosingSelf.Interface == Root {
        let isFirstRun = _container == nil
        
        guard let container = object as? Container, let storageKeyPath = storageKeyPath as? ReferenceWritableKeyPath<Container, Self> else {
            assertionFailure()
            
            return
        }
        
        self._container = container
        self._storageKeyPath = storageKeyPath
        self._lastRootID = container.interface.id
        
        if isFirstRun {
            _containerSubscription = container.objectWillChange.receive(on: DispatchQueue.main).sinkResult { [weak container] _ in
                guard let `container` = container else {
                    return
                }
                
                if container[keyPath: storageKeyPath].requiresGet {
                    container[keyPath: storageKeyPath].performGetTask()
                }
                
                container[keyPath: storageKeyPath]._lastRootID = container.interface.id
            }
        }
        
        if requiresGet {
            performGetTask()
        }
    }
    
    mutating func performGetTask() {
        guard let container = _container, let storageKeyPath = _storageKeyPath else {
            assertionFailure()
            
            return
        }
        
        guard let get = get else {
            return
        }
        
        do {
            if wrappedValue != nil || lastGetTaskResult != nil {
                wrappedValue = nil
                lastGetTaskResult = nil
            }
            
            lastGetTask = container.run(get.path, with: try get.input(container))
            lastGetTask?.onResult({ result in
                DispatchQueue.asyncOnMainIfNecessary {
                    container[keyPath: storageKeyPath]
                        .receiveGetTaskResult(result)
                }
            })
        } catch {
            lastGetTaskResult = .error(error)
        }
        
        notifyContainer()
    }
    
    mutating func receiveGetTaskResult(_ result: TaskResult<GetEndpoint.Output, Root.Error>) {
        guard let get = get else {
            assertionFailure()
            
            return
        }
        
        do {
            lastGetTask = nil
            lastGetTaskResult = try result
                .map(get.output)
                .mapError({ $0 as Swift.Error })
        } catch {
            lastGetTaskResult = .error(error)
        }
        
        _wrappedValue = lastGetTaskResult?.successValue
        
        notifyContainer()
    }
    
    func notifyContainer() {
        guard let container = _container else {
            assertionFailure()
            
            return
        }
        
        (container.objectWillChange as? opaque_VoidSender)?.send()
    }
}

extension RESTfulResourceAccessor {
    public init(
        wrappedValue: Value? = nil,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input: Initiable, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.get = EndpointConstructor(
            path: get,
            input: { _ in .init() },
            output: { $0 }
        )
        
        self.set = nil
    }
    
    public init<R0: RESTfulResourceAccessorProtocol>(
        wrappedValue: Value? = nil,
        get: KeyPath<Root, GetEndpoint>? = nil,
        from r0: KeyPath<Container, R0>
    ) where GetEndpoint.Input: RESTfulResourceConstructible, GetEndpoint.Input.Resource == R0.Value, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.get = get.map { get in
            EndpointConstructor(
                path: get,
                input: { container in
                    try .init(from: container[keyPath: r0].wrappedValue.unwrap())
                },
                output: { $0 }
            )
        }
        
        self.set = nil
    }
}

extension RESTfulResourceAccessor where SetEndpoint == NeverEndpoint<Root> {
    public init<R0: RESTfulResourceAccessorProtocol, R1: RESTfulResourceAccessorProtocol>(
        wrappedValue: Value? = nil,
        get: KeyPath<Root, GetEndpoint>? = nil,
        set: KeyPath<Root, SetEndpoint>? = nil,
        dependencies first: KeyPath<Container, R0>,
        _ second: KeyPath<Container, R1>
    ) {
        fatalError()
    }
}

// MARK: - Protocol Implementations -

extension RESTfulResourceAccessor {
    public func refresh() {
        guard let container = _container, let storageKeyPath = _storageKeyPath else {
            assertionFailure()
            
            return
        }
        
        container[keyPath: storageKeyPath].performGetTask()
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
    public enum Error: Swift.Error {
        case some
    }
}

extension RESTfulResourceAccessor {
    public struct EndpointConstructor<Endpoint: API.Endpoint> {
        public let path: KeyPath<Root, Endpoint>
        public let input: (Container) throws -> Endpoint.Input
        public let output: (Endpoint.Output) throws -> Value
        
        public init(
            path: KeyPath<Root, Endpoint>,
            input: @escaping (Container) throws -> Endpoint.Input = { _ in throw Error.some },
            output: @escaping (Endpoint.Output) throws -> Value = { _ in throw Error.some }
        ) {
            self.path = path
            self.input = input
            self.output = output
        }
    }
}

// MARK: - Helpers -

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
