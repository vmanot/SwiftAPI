//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol Request {
    associatedtype Response
    associatedtype Error: Swift.Error
    
    typealias Result = Swift.Result<Response, Error>
}
