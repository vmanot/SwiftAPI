//
// Copyright (c) Vatsal Manot
//

import Swallow
import AuthenticationServices

public protocol AuthorizationCredential: _Authentication {
    
}

public struct APIKey: AuthorizationCredential, Codable, Hashable, Sendable {
    public let serverURL: URL?
    public let value: String
    
    public init(serverURL: URL?, value: String) {
        self.serverURL = serverURL
        self.value = value
    }
}
