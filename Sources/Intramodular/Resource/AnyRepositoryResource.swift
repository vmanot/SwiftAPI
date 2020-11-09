//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public class AnyRepositoryResource<Repository: API.Repository, Value>: AnyResource<Value> {
    private var _repository: Repository?
    
    public var repository: Repository {
        _repository!
    }
    
    public init<Resource: ResourceProtocol>(
        _ resource: Resource,
        repository: Repository!
    ) where Resource.Value == Value {
        self._repository = repository
        
        super.init(resource)
    }
    
    public init<Resource: RepositoryResourceProtocol>(
        _ resource: Resource,
        _: Void = ()
    ) where Resource.Value == Value, Resource.Repository == Repository {
        self._repository = resource.repository
        
        super.init(resource)
    }
}

extension RepositoryResourceProtocol {
    public func eraseToAnyRepositoryResource() -> AnyRepositoryResource<Repository, Value> {
        .init(self)
    }
}
