//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol _opaque_PaginatedListType {
    mutating func setNextCursor(_ cursor: PaginationCursor?) throws
}

public protocol PaginatedListType: _opaque_PaginatedListType, Partializable {
    associatedtype Partial
    
    mutating func setNextCursor(_ cursor: PaginationCursor?) throws
    mutating func concatenateInPlace(_ other: Self) throws
}
