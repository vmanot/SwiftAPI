//
// Copyright (c) Vatsal Manot
//

import Swallow

public protocol EndpointBuilderPropertyWrapper: MutablePropertyWrapper, MutableEndpoint where WrappedValue == Base, Root == Base.Root, Input == Base.Input, Output == Base.Output  {
    associatedtype Base: MutableEndpoint
}

extension EndpointBuilderPropertyWrapper {
    public func buildRequest(for root: Base.Root, from input: Base.Input) throws -> Base.Root.Request {
        try wrappedValue.buildRequest(for: root, from: input)
    }
    
    public func decodeOutput(from response: Base.Root.Request.Response) throws -> Base.Output {
        try wrappedValue.decodeOutput(from: response)
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
