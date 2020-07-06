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
    var lastGetTask: Task<GetEndpoint.Output, Root.Error>?
    @usableFromInline
    var lastGetResult: TaskResult<Value, Swift.Error>?
    @usableFromInline
    var lastSetTask: Task<SetEndpoint.Output, Root.Error>?
    @usableFromInline
    var lastSetResult: TaskResult<Void, Swift.Error>?
    
    public var wrappedValue: Value? = nil
    
    public var projectedValue: Self {
        return self
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
            
            (object.objectWillChange as? opaque_VoidSender)?.send()
        }
    }
    
    @usableFromInline
    mutating func receiveEnclosingInstance<EnclosingSelf: Repository>(
        _ object:  EnclosingSelf,
        storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) where EnclosingSelf.Interface == Root {
        var isFirstRun = _container == nil
        
        guard let container = object as? Container, let storageKeyPath = storageKeyPath as? ReferenceWritableKeyPath<Container, Self> else {
            assertionFailure()
            
            return
        }
        
        self._container = container
        self._storageKeyPath = storageKeyPath
        
        if isFirstRun {
            _containerSubscription = container.objectWillChange.sinkResult { [weak container] _ in
                guard let `container` = container else {
                    return
                }
                
                if container[keyPath: storageKeyPath].wrappedValue == nil {
                    container[keyPath: storageKeyPath].performGetTask()
                }
            }
        }
        if wrappedValue == nil {
            performGetTask()
        }
    }
    
    mutating func performGetTask() {
        guard let container = _container, let storageKeyPath = _storageKeyPath else {
            assertionFailure()
            
            return
        }
        
        guard let get = get, lastGetResult == nil else {
            return
        }
        
        do {
            let task = container.run(get.path, with: try get.input(container))
            
            lastGetTask = task
            
            task.onResult({ result in
                do {
                    container[keyPath: storageKeyPath].lastGetResult = try result
                        .map(get.output)
                        .mapError({ $0 as Swift.Error })
                    
                    container[keyPath: storageKeyPath].lastGetTask = nil
                    
                    DispatchQueue.main.async {
                        (container.objectWillChange as? opaque_VoidSender)?.send()
                    }
                } catch {
                    container[keyPath: storageKeyPath].lastGetResult = .error(error)
                }
            })
        } catch {
            lastGetResult = .error(error)
        }
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
        switch resource.lastGetResult {
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
