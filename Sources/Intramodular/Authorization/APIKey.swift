//
// Copyright (c) Vatsal Manot
//

import Swallow
import AuthenticationServices

public protocol Authentication {
    
}

public protocol AuthorizationCredential: Authentication {
    
}

public struct APIKey: AuthorizationCredential {
    public let serverURL: URL
    public let password: String
}
