//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol ProgramInterface: Identifiable {
    associatedtype Root = Self
    associatedtype Request: API.Request
    associatedtype Error: ProgramInterfaceError = DefaultProgramInterfaceError<Self> where Error.Interface == Root
    
    associatedtype Models = ProgramInterfaceModels<Root>
    associatedtype Endpoints = ProgramInterfaceEndpoints<Root>
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
