//
// Copyright (c) Vatsal Manot
//

import Foundation
import Swift

public protocol APIErrorProtocol: Error {
    associatedtype API: ProgramInterface
    
    static func badRequest(
        _ error: API.Request.Error
    ) -> Self
    
    static func runtime(
        _ error: Error
    ) -> Self
}

public enum _DefaultAPIError<API: ProgramInterface>: APIErrorProtocol {
    case badRequest(API.Request.Error)
    case runtime(Error)
}

extension _DefaultAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .badRequest(let error):
                return (error as? LocalizedError)?.localizedDescription ?? error.localizedDescription
            case .runtime(let error):
                return (error as? LocalizedError)?.localizedDescription ?? error.localizedDescription
        }
    }
}
