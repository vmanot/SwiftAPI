//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol PaginatedListType: Partializable {
    associatedtype Partial
}

public protocol TokenPaginatedListType: PaginatedListType {
    associatedtype Token
    associatedtype Item
}

// MARK: - Conformances -

public struct TokenPaginatedList<Token: RequestPageToken, Item>: Initiable, TokenPaginatedListType {
    public struct Partial {
        public let items: [Item]?
        public let nextToken: Token?
        
        public init(items: [Item]?, nextToken: Token?) {
            self.items = items
            self.nextToken = nextToken
        }
    }
    
    var usedTokens: [Token?] = []
    var tail: [Token?: [Item]?] = [:]
    var head: [Item]?
    var currentToken: Token?
    var nextToken: Token?
    
    public init() {
        
    }
    
    public mutating func coalesceInPlace(with partial: Partial) throws {
        if let head = head {
            usedTokens.append(currentToken)
            tail[currentToken] = head
        }
        
        head = partial.items
        currentToken = nextToken
        nextToken = partial.nextToken
    }
}
