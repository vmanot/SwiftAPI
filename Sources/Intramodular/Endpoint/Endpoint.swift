//
// Copyright (c) Vatsal Manot
//

import Combine
import Swallow

public struct DefaultEndpointOptions: ExpressibleByNilLiteral {
    public init() {
        
    }
    
    public init(nilLiteral: Void) {
        
    }
}

/// An type that represents an API's endpoint.
public protocol Endpoint: AnyProtocol {
    /// The API this endpoint is associated to.
    
    associatedtype Root: ProgramInterface
    /// The endpoint's input type.
    associatedtype Input
    /// The endpoint's output type.
    associatedtype Output
    
    /// The endpoint's options.
    associatedtype Options = DefaultEndpointOptions
    
    /// The request type used by the endpoint.
    typealias Request = Root.Request
    
    /// Build a request.
    ///
    /// - Parameter root: The API that this endpoint belongs to.
    /// - Parameter input: The input required to construct a request for the endpoint.
    func buildRequest(
        from input: Input,
        context: EndpointBuildRequestContext<Root, Input, Output, Options>
    ) throws -> Request
    
    /// Decode output.
    ///
    /// - Parameter response: The request response to decode into the endpoint's output.
    func decodeOutput(
        from response: Request.Response,
        context: EndpointDecodeOutputContext<Root, Input, Output, Options>
    ) throws -> Output
}

// MARK: - Auxiliary Implementation -

public struct EndpointBuildRequestContext<Root: ProgramInterface, Input, Output, Options> {
    public let root: Root
    
    public init(root: Root) {
        self.root = root
    }
}

public struct EndpointDecodeOutputContext<Root: ProgramInterface, Input, Output, Options> {
    public let root: Root
    public let input: Input
    public let request: Root.Request
    
    public init(root: Root, input: Input, request: Root.Request) {
        self.root = root
        self.input = input
        self.request = request
    }
}

/// An unreachable endpoint.
public struct NeverEndpoint<Root: ProgramInterface>: Endpoint {
    public typealias Input = Never
    public typealias Output = Never
    public typealias Options = DefaultEndpointOptions
    public typealias Request = Root.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output, Options>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output, Options>
    
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
        fatalError(reason: .impossible)
    }
}
