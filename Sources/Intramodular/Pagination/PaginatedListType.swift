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
    
    private var usedTokens: [PaginationCursor?] = []
    private var tail: [PaginationCursor?: [Item]?] = [:]
    private var head: [Item]?
    private var currentToken: PaginationCursor?
    private var nextToken: PaginationCursor?
    
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
