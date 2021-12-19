//
// Copyright (c) Vatsal Manot
//

import Dispatch
import Merge
import Swallow

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
    
    fileprivate weak var repository: Container?
    
    fileprivate let cancellables = Cancellables()
    fileprivate let base: Resource
    fileprivate var repositorySubscription: AnyCancellable?
    
    public var projectedValue: AnyResource<Value> {
        .init(base)
    }
    
    public var wrappedValue: Value? {
        get {
            base.latestValue
        } set {
            base.latestValue = newValue
        }
    }
    
    init(
        persistentIdentifier: AnyCodingKey?,
        get: Resource.EndpointCoordinator<GetEndpoint>,
        set: Resource.EndpointCoordinator<SetEndpoint>
    ) {
        var configuration = ResourceConfiguration<Value>()
        
        configuration.persistentIdentifier = persistentIdentifier
        
        self.base = .init(
            configuration: configuration,
            get: get,
            set: set
        )
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
        guard let repository = object as? Container else {
            assertionFailure()
            
            return
        }
        
        self.repository = repository
        self.base._repository = repository
    }
}

// MARK: - Initializers -

extension RESTfulResourceAccessor {
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        _ getValueKeyPath: KeyPath<GetEndpoint.Output, Value>
    ) where GetEndpoint.Input: Initiable, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { _ in .init() },
                output: { $0[keyPath: getValueKeyPath] }
            ),
            set: .init()
        )
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input: ExpressibleByNilLiteral, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { _ in .init(nilLiteral: ()) },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input: Initiable, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { _ in .init() },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>
    ) where GetEndpoint.Input == Void, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { _ in () },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    // MARK: - Dependent Output
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from getInput: GetEndpoint.Input
    ) where GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { _ in getInput },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from getInput: @escaping (Container) throws -> GetEndpoint.Input
    ) where GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { try getInput($0) },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    public convenience init<WrappedInput>(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from getInput: @escaping (Container) throws -> WrappedInput
    ) where GetEndpoint.Input == Optional<WrappedInput>, GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { try getInput($0) },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from input: KeyPath<Container, GetEndpoint.Input>
    ) where GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { $0[keyPath: input] },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        from input: KeyPath<Container, GetEndpoint.Input?>
    ) where GetEndpoint.Output == Value, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { try $0[keyPath: input].unwrap() },
                output: { $0 }
            ),
            set: .init()
        )
    }
    
    // MARK: - Transform
    
    /// e.g. `@Resource(get: \.foo, { $0.bar }) var bar: Bar?`
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        _ transform: @escaping (GetEndpoint.Output) throws -> Value
    ) where GetEndpoint.Input == Void, SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { _ in () },
                output: { try transform($0) }
            ),
            set: .init()
        )
    }

    // MARK: - Dependent Output + Transform
    
    /// e.g. `@Resource(get: \.foo, \GetFooOutput.bar, from: baz) var bar: Bar?`
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        _ transform: KeyPath<GetEndpoint.Output, Value>,
        from input: KeyPath<Container, GetEndpoint.Input>
    ) where SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { $0[keyPath: input] },
                output: { $0[keyPath: transform] }
            ),
            set: .init()
        )
    }
    
    /// e.g. `@Resource(get: \.foo, \GetFooOutput.bar, from: baz) var bar: Bar?`
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        _ transform: KeyPath<GetEndpoint.Output, Value>,
        from input: KeyPath<Container, GetEndpoint.Input?>
    ) where SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { try $0[keyPath: input].unwrap() },
                output: { $0[keyPath: transform] }
            ),
            set: .init()
        )
    }

    /// e.g. `@Resource(get: \.foo, \GetFooOutput.bar, from: baz) var bar: Bar?`
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        _ transform: KeyPath<GetEndpoint.Output, Value?>,
        from input: KeyPath<Container, GetEndpoint.Input>
    ) where SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { $0[keyPath: input] },
                output: { try $0[keyPath: transform].unwrap() }
            ),
            set: .init()
        )
    }

    /// e.g. `@Resource(get: \.foo, \GetFooOutput.bar, from: baz) var bar: Bar?`
    public convenience init(
        wrappedValue: Value? = nil,
        _ persistentIdentifier: AnyCodingKey? = nil,
        get: KeyPath<Root, GetEndpoint>,
        _ transform: KeyPath<GetEndpoint.Output, Value?>,
        from input: KeyPath<Container, GetEndpoint.Input?>
    ) where SetEndpoint == NeverEndpoint<Root> {
        self.init(
            persistentIdentifier: persistentIdentifier,
            get: .init(
                dependencyGraph: { _ in [] },
                endpoint: get,
                input: { try $0[keyPath: input].unwrap() },
                output: { try $0[keyPath: transform].unwrap() }
            ),
            set: .init()
        )
    }
}

// MARK: - API -

extension Repository where Interface: RESTfulInterface {
    public typealias Resource<Value, GetEndpoint: Endpoint, SetEndpoint: Endpoint> = RESTfulResourceAccessor<
        Value,
        Self,
        GetEndpoint,
        SetEndpoint
    > where GetEndpoint.Root == Interface, SetEndpoint.Root == Interface
}