//
// Copyright (c) Vatsal Manot
//

import Combine
import Merge
import Swift

public protocol _opaque_ResourceProtocol {
    
}

public protocol ResourceProtocol: _opaque_ResourceProtocol, ObservableObject {
    associatedtype Value
    associatedtype ValueStreamPublisher: Publisher where ValueStreamPublisher.Output == Result<Value, Error>, ValueStreamPublisher.Failure == Never
    
    var publisher: ValueStreamPublisher { get }
    var latestValue: Value? { get }
    
    func unwrap() throws -> Value? 
    
    func fetch() -> AnyTask<Value, Error>
}

public protocol RepositoryResourceProtocol: ResourceProtocol {
    associatedtype Repository: API.Repository
    
    var repository: Repository { get }
}
