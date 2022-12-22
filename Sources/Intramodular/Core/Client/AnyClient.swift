//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Merge
import Swallow

public final class AnyClient<Interface: ProgramInterface, Session: RequestSession>: Client where Interface.Request == Session.Request {
    public typealias SessionCache = AnyKeyedCache<Session.Request, Session.Request.Response>
    
    private let getInterface: () -> Interface
    private let getSession: () -> Session
    private let getSessionCache: () -> SessionCache
    
    public let objectWillChange: AnyObjectWillChangePublisher
    
    public var interface: Interface {
        getInterface()
    }
    
    public var session: Session {
        getSession()
    }
    
    public var sessionCache: SessionCache {
        getSessionCache()
    }
    
    public init<Client: API.Client>(
        _ client: Client
    ) where Client.Interface == Interface, Client.Session == Session {
        self.objectWillChange = .init(from: client)
        self.getInterface = { client.interface }
        self.getSession = { client.session }
        self.getSessionCache = { AnyKeyedCache(client.sessionCache) }
    }
}
