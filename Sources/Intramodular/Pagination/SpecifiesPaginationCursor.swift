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
