//
// Copyright (c) Vatsal Manot
//

import Merge
import ObjectiveC
import Swift

public protocol RequestSession {
    associatedtype Request: API.Request
    associatedtype TaskPublisher: Publisher where TaskPublisher.Output == Request.Response, TaskPublisher.Failure == Request.Error
    
    var cancellables: Cancellables { get }
    
    func task(with _: Request) -> TaskPublisher
}

// MARK: - Implementation -

private var cancellables_objcAssociationKey: Void = ()

extension RequestSession where Self: AnyObject {
    public var cancellables: Cancellables {
        if let result = objc_getAssociatedObject(self, &cancellables_objcAssociationKey) as? Cancellables {
            return result
        } else {
            let result = Cancellables()
            
            objc_setAssociatedObject(self, &cancellables_objcAssociationKey, result, .OBJC_ASSOCIATION_RETAIN)
            
            return result
        }
    }
}

// MARK: - Concrete Implementations -

public final class AnyRequestSession<R: Request>: ObservableObject, RequestSession {
    private let cancellablesImpl: () -> Cancellables
    private let taskImpl: (R) -> AnyPublisher<R.Response, R.Error>
    
    public var cancellables: Cancellables {
        cancellablesImpl()
    }
    
    public init<S: RequestSession>(_ session: S) where S.Request == R {
        self.cancellablesImpl = { session.cancellables }
        self.taskImpl = { session.task(with: $0).eraseToAnyPublisher() }
    }
    
    public func task(with request: R) -> AnyPublisher<R.Response, R.Error> {
        taskImpl(request)
    }
}
