//
// Copyright (c) Vatsal Manot
//

import Merge
import Swift

public protocol ProgramInterface {
    associatedtype Request: API.Request
    associatedtype Error: ProgramInterfaceError = DefaultProgramInterfaceError<Self> where Error.Interface == Self
}
