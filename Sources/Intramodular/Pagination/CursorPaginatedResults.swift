//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

/// An async iterator that generates a sequence of cursor-paginated list partials.
public class AsyncCursorPaginatedResponseIterator<Item>: AsyncIteratorProtocol {
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
    
    public func next() async throws -> CursorPaginatedList<Item>.Partial? {
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

public class CursorPaginatedResults<Item>: ObservableObject, @unchecked Sendable, Sequence  {
    private let taskQueue = AsyncTaskQueue()
    private let makeResponseIterator: () -> AsyncCursorPaginatedResponseIterator<Item>
    
    @Published private var currentPaginatedList = CursorPaginatedList<Item>()
    
    public init(
        _ iterator: @escaping () -> AsyncCursorPaginatedResponseIterator<Item>
    ) {
        self.makeResponseIterator = iterator
    }
    
    public func fetch() {
        taskQueue.queue {
            if let partial = try await self.makeResponseIterator().next() {
                try self.currentPaginatedList.coalesceInPlace(with: partial)
            }
        }
    }
    
    public func makeIterator() -> AnyIterator<Item> {
        currentPaginatedList.makeIterator()
    }
}
