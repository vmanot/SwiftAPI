//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

public protocol RequestSession {
    associatedtype Request: API.Request
    
    func task(with _: Request) -> Future<Request.Response, Request.Error>
}

// MARK: - Helpers -

public struct AnyRequestSession<R: Request> {
    private let taskImpl: (R) -> Future<R.Response, R.Error>
    
    public init<S: RequestSession>(_ session: S) where S.Request == R {
        self.taskImpl = session.task
    }
    
    public func task(with request: R) -> Future<R.Response, R.Error> {
        taskImpl(request)
    }
}
