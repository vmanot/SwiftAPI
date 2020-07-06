//
// Copyright (c) Vatsal Manot
//

import Combine
import Swallow

public protocol Endpoint {
    associatedtype Root: ProgramInterface
    
    associatedtype Input: Encodable
    associatedtype Output: Decodable
    
    func buildRequest(for _: Root, from _: Input) throws -> Root.Request
    func decodeOutput(from _: Root.Request.Response) throws -> Output
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
