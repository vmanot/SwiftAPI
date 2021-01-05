//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public class AnyResource<Value>: ResourceProtocol {
    public let base: _opaque_ResourceProtocol
    public let objectWillChange: AnyObjectWillChangePublisher
    public let publisher: AnyPublisher<Result<Value, Error>, Never>
    
    let latestValueImpl: () -> Value?
    let unwrapImpl: () throws -> Value?
    let fetchImpl: () -> AnyTask<Value, Error>
    
    public var latestValue: Value? {
        latestValueImpl()
    }
    
    public init<Resource: ResourceProtocol>(
        _ resource: Resource
    ) where Resource.Value == Value {
        self.base = resource
        self.objectWillChange = .init(from: resource)
        self.publisher = resource.publisher.eraseToAnyPublisher()
        
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
