//
// Copyright (c) Vatsal Manot
//

import Swift

/// An endpoint whose core functions can be modified.
public protocol ModifiableEndpoint: Endpoint {
    typealias BuildRequestTransformContext = TransformModifiableEndpointBuildRequestContext<
        Root, Input, Output, Options
    >
    
    typealias DecodeOutputTransformContext = TransformModifiableEndpointDecodeOutputContext<
        Root, Input, Output, Options
    >

    func addBuildRequestTransform(
        _ transform: @escaping (
            Request, TransformModifiableEndpointBuildRequestContext<Root, Input, Output, Options>
        ) throws -> Request
    )
}

extension ModifiableEndpoint {
    public typealias BuildRequestContext = EndpointBuildRequestContext<Root, Input, Output, Options>
    public typealias DecodeOutputContext = EndpointDecodeOutputContext<Root, Input, Output, Options>
}

// MARK: - Auxiliary

public struct TransformModifiableEndpointBuildRequestContext<Root: APISpecification, Input, Output, Options> {
    public let root: Root
    public let input: Input
    public let options: Options
}

public struct TransformModifiableEndpointDecodeOutputContext<Root: APISpecification, Input, Output, Options> {
    public let root: Root
    public let input: Input
    public let options: Options
}
