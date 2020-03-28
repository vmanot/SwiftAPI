//
// Copyright (c) Vatsal Manot
//

import Swift

public struct RequestBuilderParametrizer<Base: RequestBuilder, Parameters>: RequestBuilder where Base.RequestParameters == Void {
    private let base: Base
    private let parametrize: (Base, Parameters) throws -> Base
    
    public init(
        base: Base,
        parametrize: @escaping (Base, Parameters) throws -> Base
    ) {
        self.base = base
        self.parametrize = parametrize
    }
    
    public func buildRequest(with parameters: Parameters) throws -> Base.Request {
        try parametrize(base, parameters).buildRequest(with: ())
    }
}

extension RequestBuilder {
    public func parametrize<Parameters>(
        with parametrize: @escaping (Self, Parameters) throws -> Self
    ) -> RequestBuilderParametrizer<Self, Parameters> {
        .init(base: self, parametrize: parametrize)
    }
}
