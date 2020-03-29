//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol ApplicationProgramInterface {
    associatedtype Request: API.Request
    associatedtype Failure: Error = Request.Error
    
    var name: String { get }
}

// MARK: - Implementation -

extension ApplicationProgramInterface {
    public var name: String {
        "Application Program Interface"
    }
}
