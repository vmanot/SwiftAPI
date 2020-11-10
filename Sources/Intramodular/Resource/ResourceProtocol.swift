//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol ResourceProtocol: _opaque_ResourceProtocol, ObservableObject {
    associatedtype Value
    
    var latestValue: Value? { get }
    
    func beginResolutionIfNecessary()
}

public protocol RepositoryResourceProtocol: ResourceProtocol {
    associatedtype Repository: API.Repository
    
    var repository: Repository { get }
}
