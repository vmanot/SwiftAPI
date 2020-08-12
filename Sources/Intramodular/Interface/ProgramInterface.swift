//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

/// A type that represents an application programming interface.
public protocol ProgramInterface: Identifiable {
    associatedtype Root = Self
    associatedtype Request: API.Request where Root.Request == Request
    associatedtype Error: ProgramInterfaceError = DefaultProgramInterfaceError<Self> where Error.Interface == Root
}

// MARK: - Auxiliary Implementation -

public struct EmptyProgramInterface<Root: ProgramInterface, Request: API.Request, Error: ProgramInterfaceError> {
    public init() {
        
    }
}
