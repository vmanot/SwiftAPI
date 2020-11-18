//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol PaginatedRequestResponse {
    associatedtype PaginatedListRepresentation: PaginatedListType
    
    func convert() throws -> PaginatedListRepresentation.Partial
}

public protocol TokenPaginatedRequestResponse: PaginatedRequestResponse where PaginatedListRepresentation: TokenPaginatedListType {
    typealias PageToken = PaginatedListRepresentation.Token
}
