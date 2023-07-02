//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol Request: Hashable {
    associatedtype Response
    associatedtype Error: _ErrorX
    
    typealias Result = Swift.Result<Response, Error>
}
