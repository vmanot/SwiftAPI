//
// Copyright (c) Vatsal Manot
//

import Combine
import Swallow

/// An type that represents an endpoint of some API.
public protocol Endpoint {
    /// The API this endpoint is associated to.
    associatedtype Root: ProgramInterface
    
    /// The endpoint's input.
    associatedtype Input: Encodable
    
    /// The endpoint's output.
    associatedtype Output: Decodable
    
    /// Build a request.
    ///
    /// - Parameter root: The API that this endpoint belongs to.
    /// - Parameter input: The input required to construct a request for the endpoint.
    func buildRequest(for root: Root, from input: Input) throws -> Root.Request
    
    /// Decode output.
    ///
    /// - Parameter response: The request response to decode into the endpoint's output.
    func decodeOutput(from response: Root.Request.Response) throws -> Output
}

// MARK: - Auxiliary Implementation -

public struct NeverEndpoint<Root: ProgramInterface>: Endpoint {
    public typealias Input = Never
    public typealias Output = Never
    
    public func buildRequest(for _: Root, from _: Input) throws -> Root.Request {
        Never.materialize(reason: .impossible)
    }
    
    public func decodeOutput(from _: Root.Request.Response) throws -> Output {
        Never.materialize(reason: .impossible)
    }
}
