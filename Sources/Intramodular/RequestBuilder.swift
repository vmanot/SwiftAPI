//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

public protocol RequestBuilder {
    associatedtype Request: API.Request
    
    func buildRequest() throws -> Request
}

public protocol RequestCoordinator: RequestBuilder, RequestResponseTransformer {
    func task<S: RequestSession>(in session: S)
        -> Future<Output, Error> where S.Request == Request
}
