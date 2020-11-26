//
// Copyright (c) Vatsal Manot
//

import Swallow

open class MutableEndpointBase<Root: ProgramInterface, Input, Output, Options>: MutableEndpoint, Initiable {
    public typealias Request = Root.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output, Options>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output, Options>
    
    private var buildRequestTransform: (_ request: Root.Request, _ context: BuildRequestTransformContext) throws -> Root.Request = { request, context in request }
    private var outputTransform: (_ output: Output, _ context: TransformOutputContext) throws -> Output = { output, context in output }
    
    public var wrappedValue: MutableEndpointBase<Root, Input, Output, Options> {
        get {
            self
        } set {
            self.buildRequestTransform = newValue.buildRequestTransform
        }
    }
    
    public required init() {
        
    }
    
    public required init<Descriptor: EndpointDescriptor>(_ descriptor: Descriptor.Type) where Descriptor.Input == Input, Descriptor.Output == Output, Options == Void {
        
    }
    
    open func buildRequestBase(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {
        throw Never.Reason.abstract
    }
    
    open func decodeOutputBase(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        throw Never.Reason.abstract
    }
    
    public final func buildRequest(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {
        try buildRequestTransform(try buildRequestBase(from: input, context: context), .init(root: context.root, input: input))
    }
    
    public final func decodeOutput(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        try outputTransform(try decodeOutputBase(from: response, context: context), .init(root: context.root, input: context.input))
    }
    
    public final func addBuildRequestTransform(
        _ transform: @escaping (Request, BuildRequestTransformContext) throws -> Request
    ) {
        let oldTransform = buildRequestTransform
        
        buildRequestTransform = { try transform(oldTransform($0, $1), $1) }
    }
}
