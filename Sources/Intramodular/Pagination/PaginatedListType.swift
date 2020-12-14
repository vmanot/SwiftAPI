//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol PaginatedListType: Partializable {
    associatedtype Partial
}

// MARK: - Conformances -

public struct TokenPaginatedList<Item>: Initiable, PaginatedListType {
    public struct Partial {
        public let items: [Item]?
        public let nextToken: PaginationCursor?
        
        public init(items: [Item]?, nextToken: PaginationCursor?) {
            self.items = items
            self.nextToken = nextToken
        }
    }
    
    var usedTokens: [PaginationCursor?] = []
    var tail: [PaginationCursor?: [Item]?] = [:]
    var head: [Item]?
    var currentToken: PaginationCursor?
    var nextToken: PaginationCursor?
    
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
