//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public struct AnyEndpoint<Root: ProgramInterface, Input, Output> {
    private var buildRequestImpl: (_ for: Root, _ from: Input) throws -> Root.Request
    private var decodeOutputImpl: (_ from: Root.Request.Response) throws -> Output
    
    public init<E: Endpoint>(_ endpoint: E) where E.Root == Root, E.Input == Input, E.Output == Output {
        self.buildRequestImpl = endpoint.buildRequest
        self.decodeOutputImpl = endpoint.decodeOutput
    }
    
    public func buildRequest(for root: Root, from input: Input) throws -> Root.Request {
        try buildRequestImpl(root, input)
    }
    
    public func decodeOutput(from response: Root.Request.Response) throws -> Output {
        try decodeOutputImpl(response)
    }
}

extension AnyEndpoint {
    public mutating func addRequestTransform(_ transform: @escaping (Root.Request) throws -> Root.Request) {
        let oldImpl = buildRequestImpl
        
        buildRequestImpl = { try transform(oldImpl($0, $1)) }
    }
    
    public mutating func addRequestTransform(_ transform: @escaping (Input, Root.Request) throws -> Root.Request) {
        let oldImpl = buildRequestImpl
        
        buildRequestImpl = { try transform($1, oldImpl($0, $1)) }
    }
}
