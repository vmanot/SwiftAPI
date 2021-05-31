//
// Copyright (c) Vatsal Manot
//

import Swift

public protocol ProgramInterfaceError: Error {
    associatedtype Interface: ProgramInterface
    
    static func badRequest(_ error: Interface.Request.Error) -> Self
    static func runtime(_ error: Error) -> Self
}

public enum DefaultProgramInterfaceError<Interface: ProgramInterface>: ProgramInterfaceError {
    case badRequest(Interface.Request.Error)
    case runtime(Error)
}
