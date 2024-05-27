//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import OrderedCollections
import Swift

public struct CursorPaginatedList<Item>: Initiable, PaginatedListType, Partializable {
    public enum CodingKeys: CodingKey {
        case _cursorsConsumed
        case _tail
        case _head
        case _currentCursor
        case _nextCursor
    }
    
    private var _cursorsConsumed: [PaginationCursor?] = []
    private var _tail: OrderedDictionary<PaginationCursor?, [Item]?> = [:]
    private var _head: [Item]?
    private var _currentCursor: PaginationCursor?
    private var _nextCursor: PaginationCursor?
    
    private var all: [Item] = []
    
    public var nextCursor: PaginationCursor? {
        _nextCursor
    }
    
    public init() {
        
    }
    
    public mutating func coalesceInPlace(with partial: Partial) throws {
        all.append(contentsOf: partial.items ?? [])
        
        if let head = _head {
            _cursorsConsumed.append(_currentCursor)
            
            _tail.updateValue(head, forKey: _currentCursor, insertingAt: _tail.elements.endIndex)
        }
        
        _head = partial.items
        _currentCursor = _nextCursor
        _nextCursor = partial.nextCursor
    }
    
    public mutating func setNextCursor(_ cursor: PaginationCursor?) {
        _nextCursor = cursor
    }
    
    public mutating func concatenateInPlace(with other: Self) {
        guard other._cursorsConsumed.isEmpty else {
            return assertionFailure()
        }
        
        if let nextCursor = _nextCursor, other._currentCursor != nil {
            guard nextCursor == other._currentCursor else {
                return assertionFailure("lhs.nextCursor != rhs.currentCursor")
            }
        }
        
        all.append(contentsOf: other.all)
        
        if let head = _head {
            _cursorsConsumed.append(_currentCursor)
            
            _tail.updateValue(head, forKey: _currentCursor, insertingAt: _tail.elements.endIndex)
        }
        
        _head = other._head
        _currentCursor = _nextCursor
        _nextCursor = other._nextCursor
    }
}

// MARK: - Conformances

extension CursorPaginatedList: CustomStringConvertible {
    public var description: String {
        TODO.unimplemented
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
            
            self._cursorsConsumed = try container.decode([PaginationCursor?].self, forKey: ._cursorsConsumed)
            self._tail = try container.decode(OrderedDictionary<PaginationCursor?, [Item]?>.self, forKey: ._tail)
            self._head = try container.decode([Item]?.self, forKey: ._head)
            self._currentCursor = try container.decode(PaginationCursor?.self, forKey: ._currentCursor)
            self._nextCursor = try container.decode(PaginationCursor?.self, forKey: ._nextCursor)
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

// MARK: - Auxiliary

extension CursorPaginatedList {
    public struct Partial {
        public let items: [Item]?
        public let nextCursor: PaginationCursor?
        
        public init(
            items: [Item]?,
            nextCursor: PaginationCursor?
        ) {
            self.items = items
            self.nextCursor = nextCursor
        }
        
        public func map<T>(
            _ transform: (Item) throws -> T
        ) rethrows -> CursorPaginatedList<T>.Partial {
            .init(items: try items?.map({ try transform($0) }), nextCursor: nextCursor)
        }
    }
}
