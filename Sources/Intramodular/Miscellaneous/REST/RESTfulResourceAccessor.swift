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
    Container: Client,
    GetEndpoint: Endpoint,
    SetEndpoint: Endpoint
>: ResourceAccessor where GetEndpoint.Root == Container.API, SetEndpoint.Root == Container.API {
    public typealias Resource = RESTfulResource<Value, Container, GetEndpoint, SetEndpoint>
    public typealias Root = Container.API
    
    fileprivate weak var client: Container?
    
    fileprivate let cancellables = Cancellables()
    fileprivate let base: Resource
    fileprivate var clientSubscription: AnyCancellable?
    
    public var projectedValue: _AnyResource<Value> {
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
        var configuration = _ResourceConfiguration<Value>()
        
        configuration.persistentIdentifier = persistentIdentifier
        
        self.base = .init(
            configuration: configuration,
            get: get,
            set: set
        )
    }
    
    @inlinable
    public static subscript<EnclosingSelf: Client>(
        _enclosingInstance object: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value?>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, RESTfulResourceAccessor>
    ) -> Value? where EnclosingSelf.API == Root {
        get {
            object[keyPath: storageKeyPath].receiveEnclosingInstance(object, storageKeyPath: storageKeyPath)
            
            return object[keyPath: storageKeyPath].wrappedValue
        } set {
            object[keyPath: storageKeyPath].receiveEnclosingInstance(object, storageKeyPath: storageKeyPath)
            
            object[keyPath: storageKeyPath].wrappedValue = newValue
        }
    }
    
    @usableFromInline
    func receiveEnclosingInstance<EnclosingSelf: Client>(
        _ object:  EnclosingSelf,
        storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, RESTfulResourceAccessor>
    ) where EnclosingSelf.API == Root {
        guard let client = object as? Container else {
            assertionFailure()
            
            return
        }
        
        self.client = client
        self.base._client = client
        
        if _isValueNil(self.wrappedValue) {
            projectedValue.fetch()
        }
    }
}

// MARK: - Initializers

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

// MARK: - API

extension Client where API: RESTfulInterface {
    public typealias Resource<Value, GetEndpoint: Endpoint, SetEndpoint: Endpoint> = RESTfulResourceAccessor<
        Value,
        Self,
        GetEndpoint,
        SetEndpoint
    > where GetEndpoint.Root == API, SetEndpoint.Root == API
}
