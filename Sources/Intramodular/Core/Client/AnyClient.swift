//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Merge
import Swallow

public final class AnyClient<API: APISpecification, Session: RequestSession>: Client where API.Request == Session.Request {
    public typealias SessionCache = AnyKeyedCache<Session.Request, Session.Request.Response>
    
    private let getSpecification: () -> API
    private let getSession: () -> Session
    private let getSessionCache: () -> SessionCache
    
    public let objectWillChange: AnyObjectWillChangePublisher
    
    public var interface: API {
        getSpecification()
    }
    
    public var session: Session {
        getSession()
    }
    
    public var sessionCache: SessionCache {
        getSessionCache()
    }
    
    public init<Client: SwiftAPI.Client>(
        _ client: Client
    ) where Client.API == API, Client.Session == Session {
        self.objectWillChange = .init(from: client)
        self.getSpecification = { client.interface }
        self.getSession = { client.session }
        self.getSessionCache = { AnyKeyedCache(client.sessionCache) }
    }
}
