//
// Copyright (c) Vatsal Manot
//

import Merge
import ObjectiveC
import Swift

public protocol RequestSession<Request>: _CancellablesProviding {
    associatedtype Request: SwiftAPI.Request
    associatedtype RequestTask: ObservableTask where RequestTask.Success == Request.Response, RequestTask.Error == Request.Error
    
    func task(with _: Request) -> RequestTask
}

// MARK: - Conformances

public final class AnyRequestSession<R: Request>: Identifiable, ObservableObject, RequestSession {
    public let base: any RequestSession<R>
    
    private let cancellablesImpl: () -> Cancellables
    private let taskImpl: (R) -> AnyTask<R.Response, R.Error>
    
    public var cancellables: Cancellables {
        cancellablesImpl()
    }
    
    public init<S: RequestSession>(_ session: S) where S.Request == R {
        self.base = session
        self.cancellablesImpl = { session.cancellables }
        self.taskImpl = {
            session
                .task(with: $0)
                .eraseToAnyTask()
        }
    }
    
    public func task(with request: R) -> AnyTask<R.Response, R.Error> {
        taskImpl(request)
    }
}
