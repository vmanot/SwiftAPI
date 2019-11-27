//
// Copyright (c) Vatsal Manot
//

import Combine
import ObjectiveC
import Swift

public protocol RequestSession {
    associatedtype Request: API.Request
    associatedtype TaskPublisher: Publisher where TaskPublisher.Output == Request.Response, TaskPublisher.Failure == Request.Error
    
    var cancellables: [AnyCancellable] { get set }
    
    func task(with _: Request) -> TaskPublisher
}

// MARK: - Implementation -

private var cancellables_objcAssociationKey: Void = ()

extension RequestSession where Self: AnyObject {
    public var cancellables: [AnyCancellable] {
        get {
            objc_getAssociatedObject(self, &cancellables_objcAssociationKey) as? [AnyCancellable] ?? []
        } set {
            objc_setAssociatedObject(self, &cancellables_objcAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}

// MARK: - Helpers -

public final class AnyRequestSession<R: Request>: ObservableObject, RequestSession {
    public var cancellables: [AnyCancellable] = []
    
    private let taskImpl: (R) -> AnyPublisher<R.Response, R.Error>
    
    public init<S: RequestSession>(_ session: S) where S.Request == R {
        self.taskImpl = { session.task(with: $0).eraseToAnyPublisher() }
    }
    
    public func task(with request: R) -> AnyPublisher<R.Response, R.Error> {
        taskImpl(request)
    }
}
