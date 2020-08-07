//
// Copyright (c) Vatsal Manot
//

import Swallow

@propertyWrapper
open class GenericMutableEndpoint<Root: ProgramInterface, Input, Output>: MutableEndpoint, MutablePropertyWrapper {
    public typealias WrappedValue = GenericMutableEndpoint<Root, Input, Output>
    
    private var buildRequestImpl: (_ for: Root, _ from: Input) throws -> Root.Request
    private var decodeOutputImpl: (_ from: Root.Request.Response) throws -> Output
    
    public var wrappedValue: GenericMutableEndpoint<Root, Input, Output> {
        get {
            self
        } set {
            self.buildRequestImpl = newValue.buildRequestImpl
            self.decodeOutputImpl = newValue.decodeOutputImpl
        }
    }
    
    public init() {
        fatalError()
    }
    
    public func buildRequest(for root: Root, from input: Input) throws -> Root.Request {
        try buildRequestImpl(root, input)
    }
    
    public func decodeOutput(from response: Root.Request.Response) throws -> Output {
        try decodeOutputImpl(response)
    }
    
    public func addRequestTransform(_ transform: @escaping (Root.Request) throws -> Root.Request) {
        let oldImpl = buildRequestImpl
        
        buildRequestImpl = { try transform(oldImpl($0, $1)) }
    }
    
    public func addRequestTransform(_ transform: @escaping (Input, Root.Request) throws -> Root.Request) {
        let oldImpl = buildRequestImpl
        
        buildRequestImpl = { try transform($1, oldImpl($0, $1)) }
    }
}
