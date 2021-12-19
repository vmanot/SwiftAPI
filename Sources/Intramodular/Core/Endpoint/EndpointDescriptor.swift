//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol EndpointDescriptor {
    associatedtype Input
    associatedtype Output
    associatedtype Options = Void
}
