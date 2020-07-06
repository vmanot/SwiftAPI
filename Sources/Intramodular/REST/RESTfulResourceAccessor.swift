//
// Copyright (c) Vatsal Manot
//

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
    public let get: EndpointConstructor<GetEndpoint>?
    public let set: EndpointConstructor<SetEndpoint>?
    
    public var lastGetTask: Task<GetEndpoint.Output, Root.Error>?
    public var lastGetResult: TaskResult<Value, Swift.Error>?
    
    public var lastSetTask: Task<SetEndpoint.Output, Root.Error>?
    public var lastSetResult: TaskResult<Void, Swift.Error>?
    
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
        }
    }
    
    @usableFromInline
    mutating func receiveEnclosingInstance<EnclosingSelf: Repository>(
        _ object:  EnclosingSelf,
        storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) where EnclosingSelf.Interface == Root {
        guard let object = object as? Container, let storageKeyPath = storageKeyPath as? ReferenceWritableKeyPath<Container, Self> else {
            assertionFailure()
            
            return
        }
        
        if let get = get, wrappedValue == nil {
            do {
                let task = object.run(get.path, with: try get.input(object))
                
                object[keyPath: storageKeyPath].lastGetTask = task
                
                task.onResult({ result in
                    do {
                        object[keyPath: storageKeyPath].lastGetResult = try result.map(get.output).mapError({ $0 as Swift.Error })
                    } catch {
                        object[keyPath: storageKeyPath].lastGetResult = .error(error)
                    }
                })
            } catch {
                lastGetResult = .error(error)
            }
        }
    }
}

extension RESTfulResourceAccessor {
    public init(
        wrappedValue: Value? = nil,
        get: KeyPath<Root, GetEndpoint>? = nil
    ) where GetEndpoint.Input: Initiable, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.get = get.map { get in
            EndpointConstructor(
                path: get,
                input: { _ in .init() },
                output: { $0 }
            )
        }
        
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
