//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol RequestResponseTransformable {
    associatedtype Request: API.Request
    
    init(from _: Request.Response) throws
}

// MARK: - Extensions -

extension RequestResponseTransformable {
    public static func task<Session: RequestSession>(
        with request: Request,
        in session: Session
    ) -> AnyPublisher<Self, Error> where Session.Request == Request {
        session.task(with: request).tryMap({ try Self(from: $0) }).eraseToAnyPublisher()
    }
}
