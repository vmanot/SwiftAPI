//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Merge
import Swallow

public final class AnyRepository<Interface: ProgramInterface, Session: RequestSession>: Repository where Interface.Request == Session.Request {
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
    
    public init<Repository: API.Repository>(
        _ repository: Repository
    ) where Repository.Interface == Interface, Repository.Session == Session {
        self.objectWillChange = .init(from: repository)
        self.getInterface = { repository.interface }
        self.getSession = { repository.session }
        self.getSessionCache = { AnyKeyedCache(repository.sessionCache) }
    }
}
