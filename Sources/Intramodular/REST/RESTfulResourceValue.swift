//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol RESTfulResourceValue: Decodable, Hashable {
    
}

public protocol RESTfulResourceValueConstructible {
    associatedtype ResourceValue: RESTfulResourceValue
    
    init(from _: ResourceValue) throws
}

// MARK: - Auxiliary Implementation -

extension Array: RESTfulResourceValue where Element: RESTfulResourceValue {
    
}

extension Optional: RESTfulResourceValue where Wrapped: RESTfulResourceValue {
    
}
