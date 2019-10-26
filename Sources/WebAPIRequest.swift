//
// Copyright (c) Vatsal Manot
//

import Foundation
import Network
import Swift
import Swallow

open class Request<Response> {
    open func baseURL() throws -> URL {
        throw Never.Reason.abstract
    }
    
    open func buildRequest() throws -> HTTPRequest {
        throw Never.Reason.abstract
    }
    
    open func path() throws -> String {
        throw Never.Reason.abstract
    }
}
