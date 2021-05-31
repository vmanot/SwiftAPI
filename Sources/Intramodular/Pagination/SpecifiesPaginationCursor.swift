//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol SpecifiesPaginationCursor {
    var paginationCursor: PaginationCursor? { get set }
    var fetchLimit: FetchLimit? { get }
}

extension SpecifiesPaginationCursor {
    public var fetchLimit: FetchLimit? {
        nil
    }
}

extension PaginationCursor {
    public struct Set {
        public let previous: PaginationCursor?
        public let next: PaginationCursor?
        public let last: PaginationCursor?
    }
}
