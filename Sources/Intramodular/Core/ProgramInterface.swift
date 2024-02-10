//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

@available(*, deprecated, renamed: "APISpecification")
public typealias ProgramInterface = APISpecification

/// A type that represents an API.
public protocol APISpecification: Identifiable {
    /// The root of this API.
    associatedtype Root: APISpecification = Self where Request == Root.Request
    /// The request type associated with this API.
    associatedtype Request: SwiftAPI.Request
    /// The error type associated with this API.
    associatedtype Error: APIErrorProtocol = _DefaultAPIError<Self> where Error.API == Self
    /// The data schema of this API.
    associatedtype Schema = Never
    
    func update(_ request: inout Root.Request)
}

// MARK: - Implementation

extension APISpecification {
    public func update(
        _ request: inout Root.Request
    ) {
        // do nothing
    }
}

// MARK: - Auxiliary

public struct EmptyAPISpecification<Root: APISpecification, Request: SwiftAPI.Request, Error: APIErrorProtocol> {
    public init() {
        
    }
}
