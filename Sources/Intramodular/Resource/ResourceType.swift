//
// Copyright (c) Vatsal Manot
//

import Combine
import Merge
import Swallow

public protocol _opaque_ResourceType: AnyProtocol {
    
}

public protocol ResourceType: _opaque_ResourceType, ObservableObject {
    associatedtype Value
    associatedtype ValueStreamPublisher: Publisher where ValueStreamPublisher.Output == Result<Value, Error>, ValueStreamPublisher.Failure == Never
    
    var publisher: ValueStreamPublisher { get }
    var latestValue: Value? { get }
    
    func unwrap() throws -> Value?
    
    @discardableResult
    func fetch() -> AnyTask<Value, Error>
}

public protocol RepositoryResourceType: ResourceType {
    associatedtype Repository: API.Repository
    
    var repository: Repository { get }
}
