//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public protocol PersistentIdentifier: Codable, LosslessStringConvertible, StringConvertible {
    
}

// MARK: - Conformances -

extension String: PersistentIdentifier {
    
}
