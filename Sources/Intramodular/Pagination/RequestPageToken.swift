//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol RequestPageToken: Codable & Hashable {
    
}

public protocol HasRequestPageToken {
    associatedtype PageToken: RequestPageToken
    
    var pageToken: PageToken? { get set }
}

// MARK: - Conformances -

public struct PageTokenValue<Data: Codable & Hashable>: RequestPageToken {
    public let data: Data
    
    public init(_ data: Data) {
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        data = try Data(from: decoder)
    }
    
    public func encode(to encoder: Encoder) throws {
        try data.encode(to: encoder)
    }
}
