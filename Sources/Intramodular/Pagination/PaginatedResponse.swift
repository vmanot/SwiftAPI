//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

/// A paginated response.
public protocol PaginatedResponse {
    associatedtype PaginatedListRepresentation: PaginatedListType & Partializable
    
    func convert() throws -> PartialOf<PaginatedListRepresentation>
}
