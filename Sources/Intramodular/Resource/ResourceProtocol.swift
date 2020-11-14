//
// Copyright (c) Vatsal Manot
//

import Combine
import Merge
import Swift

public protocol _opaque_ResourceProtocol {
    func resolve()
    func fetchIfNecessary()
}

public protocol ResourceProtocol: _opaque_ResourceProtocol, ObservableObject {
    associatedtype Value
    associatedtype ValuePublisher: Publisher where ValuePublisher.Output == Optional<Value>
    
    var publisher: ValuePublisher { get }
    
    var latestValue: Value? { get }
    
    func fetchIfNecessary()
}

public protocol RepositoryResourceProtocol: ResourceProtocol {
    associatedtype Repository: API.Repository
    
    var repository: Repository { get }
}
