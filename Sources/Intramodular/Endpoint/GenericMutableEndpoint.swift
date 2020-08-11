//
// Copyright (c) Vatsal Manot
//

import Swallow

@propertyWrapper
open class GenericMutableEndpoint<Root: ProgramInterface, Input, Output>: MutableEndpoint, MutablePropertyWrapper {
    public typealias WrappedValue = GenericMutableEndpoint<Root, Input, Output>
    
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
        throw Never.Reason.unimplemented
    }
    
    public func buildRequest(for root: Root, from input: Input) throws -> Root.Request {
        try buildRequestBase(for: root, from: input)
    }
    
    open func decodeOutput(from response: Root.Request.Response) throws -> Output {
        throw Never.Reason.unimplemented
    }
}

extension GenericMutableEndpoint {
    public final func addRequestTransform(_ transform: @escaping (Root.Request) throws -> Root.Request) {
        let oldTransform = transformRequest
        
        transformRequest = { try transform(oldTransform($0, $1, $2)) }
    }
    
    public final func addRequestTransform(_ transform: @escaping (Input, Root.Request) throws -> Root.Request) {
        let oldTransform = transformRequest
        
        transformRequest = { try transform($2, oldTransform($0, $1, $2)) }
    }
}
