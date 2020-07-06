//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol RESTfulResource: Decodable, Hashable {
    
}

public protocol RESTfulResourceConstructible {
    associatedtype Resource: RESTfulResource
    
    init(from resource: Resource) throws
}
