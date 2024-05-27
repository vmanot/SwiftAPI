//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

/// An async iterator that generates a sequence of cursor-paginated list partials.
public struct CursorPaginatedAsyncIteratorOf<Item>: AsyncIteratorProtocol {
    public typealias Element = CursorPaginatedList<Item>.Partial
    
    private let fetch: (PaginationCursor?) async throws -> CursorPaginatedList<Item>.Partial
    
    private var nextCursor: PaginationCursor?
    private var hasReachedEnd: Bool = false
    
    public init(
        startCursor: PaginationCursor?,
        fetch: @escaping (PaginationCursor?) async throws -> Element
    ) {
        self.nextCursor = startCursor
        self.fetch = fetch
    }
    
    public init<R: PaginatedResponse>(
        startCursor: PaginationCursor?,
        fetch: @escaping (PaginationCursor?) async throws -> R
    ) where R.PaginatedListRepresentation == CursorPaginatedList<Item> {
        self.nextCursor = startCursor
        self.fetch = {
            try await fetch($0).convert().value
        }
    }
    
    public mutating func next() async throws -> CursorPaginatedList<Item>.Partial? {
        guard !hasReachedEnd else {
            return nil
        }
        
        let result = try await fetch(nextCursor)
        
        self.nextCursor = result.nextCursor
        
        if result.nextCursor == nil {
            hasReachedEnd = true
        }
        
        return result
    }
}

public class CursorPaginatedAsyncSequenceOf<Item>: AsyncSequence {
    public typealias AsyncIterator = AnyAsyncIterator<Item>
    public typealias Element = Item

    private let makeIterator: () -> CursorPaginatedAsyncIteratorOf<Item>
    
    public init(
        _ makeIterator: @escaping () -> CursorPaginatedAsyncIteratorOf<Item>
    ) {
        self.makeIterator = makeIterator
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        makeIterator()._flatMap { element in
            element.items ?? []
        }
        .eraseToAnyAsyncIterator()
    }
}

public class ObservableCursorPaginatedResults<Item>: ObservableObject, @unchecked Sendable, Sequence  {
    private let taskQueue = ThrowingTaskQueue()
    private let makePaginatedIterator: () -> CursorPaginatedAsyncIteratorOf<Item>
    
    private lazy var currentIterator = self.makePaginatedIterator()
    
    @Published private var currentPaginatedList = CursorPaginatedList<Item>()
    
    public init(
        _ iterator: @escaping () -> CursorPaginatedAsyncIteratorOf<Item>
    ) {
        self.makePaginatedIterator = iterator
    }
    
    public func fetch() {
        taskQueue.addTask {
            if let partial = try await self.currentIterator.next() {
                try self.currentPaginatedList.coalesceInPlace(with: partial)
            }
        }
    }
    
    public func makeIterator() -> AnyIterator<Item> {
        currentPaginatedList.makeIterator()
    }
}
