//
// Copyright (c) Vatsal Manot
//

import Combine
import Swallow

/// An type that represents an API's endpoint.
public protocol Endpoint {
    /// The API this endpoint is associated to.
    associatedtype Root: APISpecification
    /// The endpoint's input type.
    associatedtype Input
    /// The endpoint's output type.
    associatedtype Output
    
    /// The endpoint's options.
    associatedtype Options
    
    /// The request type used by the endpoint.
    typealias Request = Root.Request
    
    func makeDefaultOptions() throws -> Options
    
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

// MARK: - Implementation

extension Endpoint {
    public func makeDefaultOptions() throws -> Options {
        if Options.self == Void.self {
            return () as! Options
        } else if let optionsType = Options.self as? ExpressibleByNilLiteral.Type {
            return optionsType.init(nilLiteral: ()) as! Options
        } else if let optionsType = Options.self as? Initiable.Type {
            return optionsType.init() as! Options
        } else {
            throw Never.Reason.unimplemented
        }
    }
}

// MARK: - API

extension Endpoint {
    public func input(_ type: Input.Type) -> Self {
        return self
    }
    
    public func input(_ type: Input.Type) -> Self where Options == Void {
        return self
    }
    
    public func output(_ type: Output.Type) -> Self where Options == Void {
        return self
    }
}

// MARK: - Auxiliary

public struct EndpointBuildRequestContext<Root: APISpecification, Input, Output, Options> {
    public let root: Root
    public let options: Options
    
    public init(root: Root, options: Options) {
        self.root = root
        self.options = options
    }
}

public struct EndpointDecodeOutputContext<Root: APISpecification, Input, Output, Options> {
    public let root: Root
    public let input: Input
    public let options: Options
    public let request: Root.Request
    
    public init(root: Root, input: Input, options: Options, request: Root.Request) {
        self.root = root
        self.input = input
        self.options = options
        self.request = request
    }
}

/// An unreachable endpoint.
public struct NeverEndpoint<Root: APISpecification>: Endpoint {
    public typealias Input = Never
    public typealias Output = Never
    public typealias Options = Void
    public typealias Request = Root.Request
    
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output, Options>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output, Options>
    
    public init() {
        
    }
    
    public func buildRequest(
        from input: Input,
        context: BuildRequestContext
    ) throws -> Request {

    }
    
    public func decodeOutput(
        from response: Request.Response,
        context: DecodeOutputContext
    ) throws -> Output {
        fatalError(.impossible)
    }
}
