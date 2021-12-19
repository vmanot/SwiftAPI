//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

/// A type-erased resource.
///
/// An instance of `AnyResource` forwards its operations to an underlying base resource having the same `Value` type, hiding the specifics of the underlying resource.
public class AnyResource<Value>: ResourceType {
    public typealias ValueStreamPublisher = AnyPublisher<Result<Value, Error>, Never>
    
    public let base: _opaque_ResourceType
    public let objectWillChange: AnyObjectWillChangePublisher
    
    let publisherImpl: () -> ValueStreamPublisher
    let latestValueImpl: () -> Value?
    let unwrapImpl: () throws -> Value?
    let fetchImpl: () -> AnyTask<Value, Error>
    
    @Inout
    public var configuration: ResourceConfiguration<Value>
    
    public var publisher: ValueStreamPublisher {
        publisherImpl()
    }
    
    public var latestValue: Value? {
        latestValueImpl()
    }
    
    public init<Resource: ResourceType>(
        _ resource: Resource
    ) where Resource.Value == Value {
        self.base = resource
        self.objectWillChange = .init(from: resource)
        
        self.publisherImpl = { resource.publisher.eraseToAnyPublisher() }
    
        self._configuration = .init(getter: { resource.configuration }, setter: { resource.configuration = $0 })
        self.latestValueImpl = { resource.latestValue }
        self.unwrapImpl = resource.unwrap
        self.fetchImpl = resource.fetch
    }
    
    public func unwrap() throws -> Value? {
        try unwrapImpl()
    }
    
    @discardableResult
    public func fetch() -> AnyTask<Value, Error> {
        fetchImpl()
    }
}

// MARK: - API -

extension Result {
    public init?(
        resource: AnyResource<Success>
    ) where Failure == Error {
        do {
            if let value = try resource.unwrap() {
                self = .success(value)
            } else {
                return nil
            }
        } catch {
            self = .failure(error)
        }
    }
}
