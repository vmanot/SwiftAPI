//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Foundation
import Swallow

public enum APIErrors: _SubsystemDomain {
    
}

public protocol APIErrorProtocol: _ErrorX {
    associatedtype API: APISpecification
    
    static func badRequest(
        request: API.Request?,
        error: API.Request.Error
    ) -> Self
    
    static func runtime(
        _ error: AnyError
    ) -> Self
}

extension APIErrorProtocol {
    public static func badRequest(
        _ error: API.Request.Error
    ) -> Self {
        self.badRequest(request: nil, error: error)
    }
}

// MARK: - Initializers

extension APIErrorProtocol {
    public static func runtime(
        _ error: any Error
    ) -> Self {
        .runtime(AnyError(erasing: error))
    }
    
    public init?(
        _catchAll error: AnyError
    ) throws {
        self = .runtime(error)
    }
}

// MARK: - Conformees

public enum _DefaultAPIError<API: APISpecification>: APIErrorProtocol {
    case badRequest(request: API.Request?, error: API.Request.Error)
    case runtime(AnyError)
    
    public var description: String {
        switch self {
            case .badRequest(let request, let error):
                if let error = ((error as? AnyError)?.base ?? error) as? LocalizedError {
                    return error.localizedDescription
                } else {
                    if let request {
                        return "Bad request: \(request), error: \(error)"
                    } else {
                        return "Bad request: \(error)"
                    }
                }
            case .runtime(let error):
                return error.description
        }
    }
}

extension _DefaultAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .badRequest(_, let error):
                return (error as? LocalizedError)?.localizedDescription ?? error.localizedDescription
            case .runtime(let error):
                return (error as? LocalizedError)?.localizedDescription ?? error.localizedDescription
        }
    }
}
