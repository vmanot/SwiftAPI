//
// Copyright (c) Vatsal Manot
//

import Swallow

open class GenericMutableEndpoint<Root: ProgramInterface, Input, Output>: MutableEndpoint {
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
    
    open func buildRequestBase(for root: Root, from input: Input) throws -> Root.Request {
        throw Never.Reason.abstract
    }
    
    public func buildRequest(for root: Root, from input: Input) throws -> Root.Request {
        try transformRequest(try buildRequestBase(for: root, from: input), root, input)
    }
    
    open func decodeOutput(from response: Root.Request.Response) throws -> Output {
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
