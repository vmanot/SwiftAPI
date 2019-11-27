//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol RequestResponseTransformer {
    associatedtype Request: API.Request
    associatedtype Output
    
    func transform(_: Request.Response) throws -> Output
}
