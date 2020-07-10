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

// MARK: - Auxiliary Implementation -

extension Array: RESTfulResource where Element: RESTfulResource {
    
}

extension Optional: RESTfulResource where Wrapped: RESTfulResource {
    
}
