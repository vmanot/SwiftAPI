//
// Copyright (c) Vatsal Manot
//

import Combine
import Swallow

/// An type that represents an API's endpoint.
public protocol Endpoint: AnyProtocol {
    /// The API this endpoint is associated to.
    associatedtype Root: ProgramInterface
    
    /// The endpoint's input.
    associatedtype Input
    
    /// The endpoint's output.
    associatedtype Output
    
    /// The request type used by the endpoint.
    typealias Request = Root.Request
        
    /// Build a request.
    ///
    /// - Parameter root: The API that this endpoint belongs to.
    /// - Parameter input: The input required to construct a request for the endpoint.
    func buildRequest(
        from input: Input,
        context: EndpointBuildRequestContext<Self.Root, Self.Input, Self.Output>
    ) throws -> Request
    
    /// Decode output.
    ///
    /// - Parameter response: The request response to decode into the endpoint's output.
    func decodeOutput(
        from response: Request.Response,
        context: EndpointDecodeOutputContext<Self.Root, Self.Input, Self.Output>
    ) throws -> Output
}

public protocol MutableEndpoint: Endpoint {
    mutating func addRequestTransform(_ transform: @escaping (Root.Request) throws -> Root.Request)
    mutating func addRequestTransform(_ transform: @escaping (Root.Request, Input) throws -> Root.Request)
    mutating func addRequestTransform(_ transform: @escaping (Root.Request, Root, Input) throws -> Root.Request)
}

extension MutableEndpoint {
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output>
}

// MARK: - Auxiliary Implementation -

public struct EndpointBuildRequestContext<Root: ProgramInterface, Input, Output> {
    public let root: Root
    
    public init(root: Root) {
        self.root = root
    }
}

public struct EndpointDecodeOutputContext<Root: ProgramInterface, Input, Output> {
    public let root: Root
    public let input: Input
    
    public init(root: Root, input: Input) {
        self.root = root
        self.input = input
    }
}

/// An unreachable endpoint.
public struct NeverEndpoint<Root: ProgramInterface>: Endpoint {
    public typealias Input = Never
    public typealias Output = Never
    public typealias Request = Root.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output>
    
    public init() {
        
    }
    
    public func buildRequest(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {
        Never.materialize(reason: .impossible)
    }
    
    public func decodeOutput(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        throw Never.materialize(reason: .impossible)
    }
}
