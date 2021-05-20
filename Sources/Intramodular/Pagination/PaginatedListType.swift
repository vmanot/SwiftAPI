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

public struct CursorPaginatedList<Item>: Initiable, PaginatedListType {
    public enum CodingKeys: CodingKey {
        case cursorsConsumed
        case tail
        case head
        case currentCursor
        case nextCursor
    }
    
    public struct Partial {
        public let items: [Item]?
        public let nextCursor: PaginationCursor?
        
        public init(items: [Item]?, nextCursor: PaginationCursor?) {
            self.items = items
            self.nextCursor = nextCursor
        }
    }
    
    private var cursorsConsumed: [PaginationCursor?] = []
    private var tail: OrderedDictionary<PaginationCursor?, [Item]?> = [:]
    private var head: [Item]?
    private var currentCursor: PaginationCursor?
    private var nextCursor: PaginationCursor?
    
    private var all: [Item] = []
    
    public init() {
        
    }
    
    public mutating func coalesceInPlace(with partial: Partial) throws {
        all.append(contentsOf: partial.items ?? [])
        
        if let head = head {
            cursorsConsumed.append(currentCursor)
            
            tail.insert((key: currentCursor, value: head), at: tail.endIndex)
        }
        
        head = partial.items
        currentCursor = nextCursor
        nextCursor = partial.nextCursor
    }
}

extension CursorPaginatedList: RandomAccessCollection {
    public var startIndex: Int {
        all.startIndex
    }
    
    public var endIndex: Int {
        all.endIndex
    }
    
    public subscript(position: Int) -> Item {
        all[position]
    }
    
    public func makeIterator() -> AnyIterator<Item> {
        .init(all.makeIterator())
    }
}

extension CursorPaginatedList: Encodable where Item: Encodable {
    
}

extension CursorPaginatedList: Decodable where Item: Decodable {
    public init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            self.cursorsConsumed = try container.decode([PaginationCursor?].self, forKey: .cursorsConsumed)
            self.tail = try container.decode(OrderedDictionary<PaginationCursor?, [Item]?>.self, forKey: .cursorsConsumed)
            self.head = try container.decode([Item]?.self, forKey: .cursorsConsumed)
            self.currentCursor = try container.decode(PaginationCursor?.self, forKey: .cursorsConsumed)
            self.nextCursor = try container.decode(PaginationCursor?.self, forKey: .cursorsConsumed)
        } catch {
            let container = try decoder.singleValueContainer()
            
            self.all = try container.decode([Item].self)
        }
    }
}

extension CursorPaginatedList.Partial: Equatable where Item: Equatable {
    
}

extension CursorPaginatedList.Partial: Hashable where Item: Hashable {
    
}

extension CursorPaginatedList: Equatable where Item: Equatable {
    
}

extension CursorPaginatedList: Hashable where Item: Hashable {
    
}
