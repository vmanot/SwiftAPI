//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol Request: Hashable {
    associatedtype Response
    associatedtype Error: Swift.Error
    
    typealias Result = Swift.Result<Response, Error>
}
