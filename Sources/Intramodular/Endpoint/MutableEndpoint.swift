//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol MutableEndpoint: Endpoint {
    typealias BuildRequestTransformContext = TransformMutableEndpointBuildRequestContext<Root, Input, Output, Options>
    typealias TransformOutputContext = TransformMutableEndpointOutputContext<Root, Input, Output, Options>
    
    func addBuildRequestTransform(
        _ transform: @escaping (Request, TransformMutableEndpointBuildRequestContext<Root, Input, Output, Options>) throws -> Request
    )
}

extension MutableEndpoint {
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output, Options>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output, Options>
}

// MARK: - Auxiliary Implementation -

public struct TransformMutableEndpointBuildRequestContext<Root: ProgramInterface, Input, Output, Options> {
    public let root: Root
    public let input: Input
}

public struct TransformMutableEndpointOutputContext<Root: ProgramInterface, Input, Output, Options> {
    public let root: Root
    public let input: Input
}
