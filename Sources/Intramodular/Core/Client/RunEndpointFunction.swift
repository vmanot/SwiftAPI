//
// Copyright (c) Vatsal Manot
//

import Foundation
import Merge
import Swallow

public struct _ClientRunEndpointFunction<Endpoint: SwiftAPI.Endpoint>  {
    public typealias Input = Endpoint.Input
    public typealias Options = Endpoint.Options
    public typealias Output = Endpoint.Output
    public typealias Error = Endpoint.Root.Error

    let run: (Endpoint.Input, Endpoint.Options) -> AnyTask<Output, Error>
    
    public func callAsFunction(
        _ input: Input,
        options: Options
    ) -> AnyTask<Output, Error> {
        run(input, options)
    }

    public func callAsFunction(
        _ input: Input,
        options: Options
    ) async throws -> Output {
        try await callAsFunction(input, options: options).value
    }
    
    public func callAsFunction(
        options: Options
    ) -> AnyTask<Output, Error> where Input == Void {
        run((), options)
    }
    
    public func callAsFunction(
        options: Options
    ) async throws -> Output where Input == Void {
        try await callAsFunction(options: options).value
    }

    public func callAsFunction(
        _ input: Input
    ) -> AnyTask<Output, Error> where Options == Void {
        run(input, ())
    }

    public func callAsFunction(
        _ input: Input
    ) async throws -> Output where Options == Void {
        try await callAsFunction(input).value
    }
    
    public func callAsFunction() -> AnyTask<Output, Error> where Input: ExpressibleByNilLiteral, Options == Void {
        run(nil, ())
    }

    public func callAsFunction() async throws -> Output where Input: ExpressibleByNilLiteral, Options == Void {
        try await callAsFunction().value
    }
    
    public func callAsFunction() -> AnyTask<Output, Error> where Input: ExpressibleByNilLiteral, Options: ExpressibleByNilLiteral {
        run(nil, nil)
    }

    public func callAsFunction() async throws -> Output where Input: ExpressibleByNilLiteral, Options: ExpressibleByNilLiteral {
        try await callAsFunction().value
    }

    public func callAsFunction() -> AnyTask<Output, Error> where Input == Void, Options == Void {
        run((), ())
    }

    public func callAsFunction() async throws -> Output where Input == Void, Options == Void {
        try await callAsFunction().value
    }
    
    public func callAsFunction() -> AnyTask<Output, Error> where Input == Void, Options: ExpressibleByNilLiteral {
        run((), nil)
    }

    public func callAsFunction() async throws -> Output where Input == Void, Options: ExpressibleByNilLiteral {
        try await callAsFunction().value
    }
}
