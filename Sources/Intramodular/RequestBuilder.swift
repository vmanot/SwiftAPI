//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

public protocol RequestBuilder {
    associatedtype Request: API.Request
    associatedtype RequestParameters
    
    func buildRequest(with _: RequestParameters) throws -> Request
}
