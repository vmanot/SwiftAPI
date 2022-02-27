//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

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

public class AsyncCursorPaginatedItems<Item>: ObservableObject, @unchecked Sendable  {
    private let taskQueue = AsyncTaskQueue()

    var makeResponseIterator: () -> AsyncCursorPaginatedResponseIterator<Item>

    @Published var currentPaginatedList = CursorPaginatedList<Item>()

    @Published private var fetchedItems: [Item] = []

    public init(
        _ iterator: @escaping () -> AsyncCursorPaginatedResponseIterator<Item>
    ) {
        self.makeResponseIterator = iterator
    }

    public func fetch() {
        Task {
            if let partial = try await makeResponseIterator().next() {
                try currentPaginatedList.coalesceInPlace(with: partial)
            }
        }
    }
}
