//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol MutableEndpoint: Endpoint {
    typealias BuildRequestTransformContext = TransformMutableEndpointBuildRequestContext<Root, Input, Output>
    typealias TransformOutputContext = TransformMutableEndpointOutputContext<Root, Input, Output>
    
    func addBuildRequestTransform(
        _ transform: @escaping (Request, TransformMutableEndpointBuildRequestContext<Root, Input, Output>) throws -> Request
    )
}

extension MutableEndpoint {
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output>
}

// MARK: - Auxiliary Implementation -

public struct TransformMutableEndpointBuildRequestContext<Root: ProgramInterface, Input, Output> {
    public let root: Root
    public let input: Input
}

public struct TransformMutableEndpointOutputContext<Root: ProgramInterface, Input, Output> {
    public let root: Root
    public let input: Input
}
