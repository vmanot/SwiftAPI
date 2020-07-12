//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol ProgramInterface: Identifiable {
    associatedtype Root = Self
    associatedtype Request: API.Request
    associatedtype Error: ProgramInterfaceError = DefaultProgramInterfaceError<Self> where Error.Interface == Root
}

public struct EmptyProgramInterface<Root: ProgramInterface, Request: API.Request, Error: ProgramInterfaceError> {
    public init() {
        
    }
}
