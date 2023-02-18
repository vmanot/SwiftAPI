//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

/// A cursor-paginated type.
public protocol CursorPaginated {
    var paginationCursor: PaginationCursor? { get set }
    var fetchLimit: FetchLimit? { get }
}

// MARK: - Implementation

extension CursorPaginated {
    public var fetchLimit: FetchLimit? {
        nil
    }
}
