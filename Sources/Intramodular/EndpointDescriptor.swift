//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol EndpointDescriptor {
    associatedtype Input: Encodable
    associatedtype Output: Decodable
}
