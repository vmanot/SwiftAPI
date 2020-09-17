//
// Copyright (c) Vatsal Manot
//

import Merge
import ObjectiveC
import Swift
import Task

public protocol RequestSession: CancellablesHolder, Identifiable {
    associatedtype Request: API.Request
    associatedtype RequestTask: Task where RequestTask.Success == Request.Response, RequestTask.Error == Request.Error
        
    func task(with _: Request) -> RequestTask
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

// MARK: - Conformances -

public final class AnyRequestSession<R: Request>: Identifiable, ObservableObject, RequestSession {
    private let cancellablesImpl: () -> Cancellables
    private let idImpl: () -> AnyHashable
    private let taskImpl: (R) -> AnyTask<R.Response, R.Error>
    
    public var cancellables: Cancellables {
        cancellablesImpl()
    }
    
    public var id: AnyHashable {
        idImpl()
    }
    
    public init<S: RequestSession>(_ session: S) where S.Request == R {
        self.cancellablesImpl = { session.cancellables }
        self.idImpl = { session.id }
        self.taskImpl = { session.task(with: $0).eraseToAnyTask() }
    }
    
    public func task(with request: R) -> AnyTask<R.Response, R.Error> {
        taskImpl(request)
    }
}
