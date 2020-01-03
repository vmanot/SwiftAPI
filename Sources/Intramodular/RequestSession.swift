//
// Copyright (c) Vatsal Manot
//

import Merge
import ObjectiveC
import Swift

public protocol RequestSession {
    associatedtype Request: API.Request
    associatedtype TaskPublisher: Publisher where TaskPublisher.Output == Request.Response, TaskPublisher.Failure == Request.Error
    
    var cancellables: Cancellables { get set }
    
    func task(with _: Request) -> TaskPublisher
}

// MARK: - Implementation -

private var cancellables_objcAssociationKey: Void = ()

extension RequestSession where Self: AnyObject {
    public var cancellables: Cancellables {
        get {
            objc_getAssociatedObject(self, &cancellables_objcAssociationKey) as? Cancellables ?? Cancellables()
        } set {
            objc_setAssociatedObject(self, &cancellables_objcAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - Helpers -

public final class AnyRequestSession<R: Request>: ObservableObject, RequestSession {
    public var cancellables: Cancellables
    
    private let taskImpl: (R) -> AnyPublisher<R.Response, R.Error>
    
    public init<S: RequestSession>(_ session: S) where S.Request == R {
        self.cancellables = session.cancellables
        self.taskImpl = { session.task(with: $0).eraseToAnyPublisher() }
    }
    
    public func task(with request: R) -> AnyPublisher<R.Response, R.Error> {
        taskImpl(request)
    }
    
    public func trigger(_ request: R) {
        task(with: request)
            .subscribe(storeIn: cancellables)
    }
}
