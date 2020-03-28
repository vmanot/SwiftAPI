//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public struct GenericRequestResponseTransformerFunctionality<Base: RequestBuilder, Response: Codable>: RequestBuilder, RequestResponseTransformer {
    public typealias Request = Base.Request
    public typealias RequestParameters = Base.RequestParameters
    public typealias Output = Response
    
    private let base: Base
    private let transform: (Base.Request.Response) throws -> Response
    
    public init(
        base: Base,
        transform: @escaping (Base.Request.Response) throws -> Response
    ) {
        self.base = base
        self.transform = transform
    }
    
    public func buildRequest(with parameters: Base.RequestParameters) throws -> Base.Request {
        try base.buildRequest(with: parameters)
    }
    
    public func transform(_ response: Base.Request.Response) throws -> Response {
        try transform(response)
    }
}

extension RequestBuilder {
    public func transformResponse<Response>(
        _ transform: @escaping (Request.Response) throws -> Response
    ) -> GenericRequestResponseTransformerFunctionality<Self, Response> {
        .init(base: self, transform: transform)
    }
}
