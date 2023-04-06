//
// Copyright (c) Vatsal Manot
//

import Compute
import Swallow
import Swift

public protocol _opaque_PaginatedListType {
    var nextCursor: PaginationCursor? { get }
    
    mutating func setNextCursor(_ cursor: PaginationCursor?) throws
    
    mutating func _opaque_concatenateInPlace(with other: _opaque_PaginatedListType) throws
}

extension _opaque_PaginatedListType where Self: PaginatedListType {
    public mutating func _opaque_concatenateInPlace(with other: _opaque_PaginatedListType) throws {
        try concatenateInPlace(with: cast(other, to: Self.self))
    }
}

/// A list of paginated items and associated pagination metadata.
public protocol PaginatedListType: _opaque_PaginatedListType, Sequence {
    var nextCursor: PaginationCursor? { get }
    
    mutating func setNextCursor(_ cursor: PaginationCursor?) throws
    mutating func concatenateInPlace(with other: Self) throws
}

extension _ResourcePropertyWrapperType where Value: PaginatedListType {
    public func fetchAllNext() -> AnyTask<Value, Error> {
        defer {
            if latestValue == nil {
                fetch()
            }
        }
        
        // Fetch the first available value and go to town with it.
        return publisher
            .tryMap({ try $0.get() })
            .first()
            .flatMap { value in
                Publishers.While(value.nextCursor != nil) {
                    self.fetch().successPublisher
                }
                .convertToTask()
                .successPublisher
                .mapTo({ self.latestValue })
                .tryMap({ try $0.unwrap() })
            }
            .convertToTask()
    }
}
