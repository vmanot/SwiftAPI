//
// Copyright (c) Vatsal Manot
//

import Swift

open class RESTfulRepositoryBase<Interface: RESTfulInterface, Session: RequestSession>: RepositoryBase<Interface, Session> where Interface.Request == Session.Request {
    
}
