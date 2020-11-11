//
// Copyright (c) Vatsal Manot
//

import Swallow

open class GenericMutableEndpoint<Root: ProgramInterface, Input, Output>: MutableEndpoint {
    public typealias Request = Root.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output>
    
    private var buildRequestTransform: (_ request: Root.Request, _ context: BuildRequestTransformContext) throws -> Root.Request = { request, context in request }
    
    public var wrappedValue: GenericMutableEndpoint<Root, Input, Output> {
        get {
            self
        } set {
            self.buildRequestTransform = newValue.buildRequestTransform
        }
    }
    
    public init() {
        
    }
    
    open func buildRequestBase(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {
        throw Never.Reason.abstract
    }
    
    public func buildRequest(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {
        try buildRequestTransform(try buildRequestBase(from: input, context: context), .init(root: context.root, input: input))
    }
    
    open func decodeOutput(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        throw Never.Reason.abstract
    }

    public final func addBuildRequestTransform(
        _ transform: @escaping (Request, BuildRequestTransformContext) throws -> Request
    ) {
        let oldTransform = buildRequestTransform
        
        buildRequestTransform = { try transform(oldTransform($0, $1), $1) }
    }
}
