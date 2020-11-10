//
// Copyright (c) Vatsal Manot
//

import Swallow

public protocol EndpointBuilderPropertyWrapper: MutablePropertyWrapper, MutableEndpoint where WrappedValue == Base, Root == Base.Root, Input == Base.Input, Output == Base.Output  {
    associatedtype Base: MutableEndpoint
}

extension EndpointBuilderPropertyWrapper {
    public typealias Request = Base.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Base.Root, Base.Input, Base.Output>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Base.Root, Base.Input, Base.Output>
    
    public func buildRequest(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {
        try wrappedValue.buildRequest(from: input, context: context)
    }
    
    public func decodeOutput(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        try wrappedValue.decodeOutput(from: response, context: context)
    }
    
    public mutating func addRequestTransform(_ transform: @escaping (Base.Root.Request) throws -> Base.Root.Request) {
        wrappedValue.addRequestTransform(transform)
    }
    
    public mutating func addRequestTransform(_ transform: @escaping (Base.Root.Request, Base.Input) throws -> Base.Root.Request) {
        wrappedValue.addRequestTransform(transform)
    }
    
    public mutating func addRequestTransform(_ transform: @escaping (Base.Root.Request, Base.Root, Base.Input) throws -> Base.Root.Request) {
        wrappedValue.addRequestTransform(transform)
    }
}
