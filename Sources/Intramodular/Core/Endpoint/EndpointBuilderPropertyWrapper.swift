//
// Copyright (c) Vatsal Manot
//

import Swallow

/// A property wrapper that refines an endpoint.
public protocol EndpointBuilderPropertyWrapper: MutablePropertyWrapper, ModifiableEndpoint where WrappedValue == Base, Root == Base.Root, Input == Base.Input, Output == Base.Output, Options == Base.Options {
    associatedtype Base: ModifiableEndpoint
}

extension EndpointBuilderPropertyWrapper {
    public typealias Request = Base.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Base.Root, Base.Input, Base.Output, Base.Options>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Base.Root, Base.Input, Base.Output, Base.Options>
    
    public func makeDefaultOptions() throws -> Options {
        try wrappedValue.makeDefaultOptions()
    }
    
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
    
    public func addBuildRequestTransform(
        _ transform: @escaping (Request, BuildRequestTransformContext) throws -> Request
    ) {
        wrappedValue.addBuildRequestTransform(transform)
    }
}
