//
// Copyright (c) Vatsal Manot
//

import Swallow

open class GenericMutableEndpoint<Root: ProgramInterface, Input, Output>: MutableEndpoint {
    public typealias Request = Root.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output>
    
    private var transformRequest: (_ base: Root.Request, _ for: Root, _ from: Input) throws -> Root.Request = { base, root, input in base }
    
    public var wrappedValue: GenericMutableEndpoint<Root, Input, Output> {
        get {
            self
        } set {
            self.transformRequest = newValue.transformRequest
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
        try transformRequest(try buildRequestBase(from: input, context: context), context.root, input)
    }
    
    open func decodeOutput(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        throw Never.Reason.abstract
    }
}

extension GenericMutableEndpoint {
    public final func addRequestTransform(_ transform: @escaping (Root.Request) throws -> Root.Request) {
        let oldTransform = transformRequest
        
        transformRequest = { try transform(oldTransform($0, $1, $2)) }
    }
    
    public final func addRequestTransform(_ transform: @escaping (Root.Request, Input) throws -> Root.Request) {
        let oldTransform = transformRequest
        
        transformRequest = { try transform(oldTransform($0, $1, $2), $2) }
    }
    
    public final func addRequestTransform(_ transform: @escaping (Root.Request, Root, Input) throws -> Root.Request) {
        let oldTransform = transformRequest
        
        transformRequest = { try transform(oldTransform($0, $1, $2), $1, $2) }
    }
}
