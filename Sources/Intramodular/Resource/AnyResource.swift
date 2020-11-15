//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow
import Task

public class AnyResource<Value>: ResourceProtocol {
    public let base: _opaque_ResourceProtocol
    public let objectWillChange: AnyObjectWillChangePublisher
    public let publisher: AnyPublisher<Result<Value, Error>, Never>
    
    let latestValueImpl: () -> Value?
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
        self.fetchImpl = resource.fetch
    }
    
    @discardableResult
    public func fetch() -> AnyTask<Value, Error> {
        fetchImpl()
    }
}
