//
// Copyright (c) Vatsal Manot
//

import Foundation
import Merge
import Swallow

public struct RunEndpointFunction<Endpoint: API.Endpoint>  {
    let run: (Endpoint.Input, Endpoint.Options) -> AnyTask<Endpoint.Output, Endpoint.Root.Error>
    
    public func callAsFunction(_ input: (Endpoint.Input), options: Endpoint.Options) -> AnyTask<Endpoint.Output, Endpoint.Root.Error> {
        run(input, options)
    }
    
    public func callAsFunction(_ input: (Endpoint.Input)) -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Options == Void {
        run(input, ())
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input: ExpressibleByNilLiteral, Endpoint.Options == Void {
        run(nil, ())
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input: ExpressibleByNilLiteral, Endpoint.Options: ExpressibleByNilLiteral {
        run(nil, nil)
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input == Void, Endpoint.Options == Void {
        run((), ())
    }
    
    public func callAsFunction() -> AnyTask<Endpoint.Output, Endpoint.Root.Error> where Endpoint.Input == Void, Endpoint.Options: ExpressibleByNilLiteral {
        run((), nil)
    }
}
