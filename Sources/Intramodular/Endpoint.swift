//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

public protocol Endpoint {
    associatedtype Root: ProgramInterface
    
    associatedtype Input: Encodable
    associatedtype Output: Decodable
    
    func buildRequest(for _: Root, from _: Input) throws -> Root.Request
    func decodeOutput(from _: Root.Request.Response) throws -> Output
}
