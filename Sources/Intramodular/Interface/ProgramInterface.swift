//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol ProgramInterface: Identifiable {
    associatedtype Root = Self
    associatedtype Request: API.Request where Root.Request == Request
    associatedtype Error: ProgramInterfaceError = DefaultProgramInterfaceError<Self> where Error.Interface == Root
    
    associatedtype Models = ProgramInterfaceModels<Self>
    associatedtype Endpoints = ProgramInterfaceEndpoints<Self>
}

// MARK: - Auxiliary Implementation -

public struct ProgramInterfaceModels<Root: ProgramInterface> {
    
}

public struct ProgramInterfaceEndpoints<Root: ProgramInterface> {
    
}

public struct EmptyProgramInterface<Root: ProgramInterface, Request: API.Request, Error: ProgramInterfaceError> {
    public init() {
        
    }
}
