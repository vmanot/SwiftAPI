//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow
import Task

public final class AnyRepository<Interface: ProgramInterface, Session: RequestSession>: Repository where Interface.Request == Session.Request {
    private let getInterface: () -> Interface
    private let getSession: () -> Session
    
    public let objectWillChange: AnyObjectWillChangePublisher
    
    public var interface: Interface {
        getInterface()
    }
    
    public var session: Session {
        getSession()
    }
    
    public init<Repository: API.Repository>(
        _ repository: Repository
    ) where Repository.Interface == Interface, Repository.Session == Session {
        self.objectWillChange = .init(from: repository)
        self.getInterface = { repository.interface }
        self.getSession = { repository.session }
    }
}
