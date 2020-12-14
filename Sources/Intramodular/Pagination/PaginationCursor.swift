//
// Copyright (c) Vatsal Manot
//

#if canImport(CloudKit)
import CloudKit
#endif
import Compute
import FoundationX
import Swift

public enum PaginationCursor: Hashable {
    case data(Data)
    case string(String)
    
    case offset(Int)
    
    #if canImport(CloudKit)
    case cloudKitQueryCursor(CKQueryOperation.Cursor)
    #endif
    
    case value(AnyHashable)
}


extension PaginationCursor {
    public var stringValue: String? {
        guard case let .string(string) = self else {
            return nil
        }
        
        return string
    }
}

extension PaginationCursor {
    public enum _Type: String, Codable {
        case data
        case string
        case offset
        case cloudKitQueryCursor
        case value
    }
}

// MARK: - Protocol Conformances -

extension PaginationCursor: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let data = try? container.decode(Data.self) {
            self = .data(data)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let offset = try? container.decode(Int.self) {
            self = .offset(offset)
        } else {
            throw Never.Reason.unimplemented
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch self {
            case .data(let data):
                try container.encode(data)
            case .string(let string):
                try container.encode(string)
            case .offset(let offset):
                try container.encode(offset)
            case .cloudKitQueryCursor(let cursor):
                try container.encode(try cursor.archiveUsingKeyedArchiver()) // FIXME!!!
            case .value:
                throw Never.Reason.unimplemented
        }
    }
}

// MARK: - Auxiliary Implementation -

public enum PaginationLimit: ExpressibleByIntegerLiteral, ExpressibleByNilLiteral {
    case offset(Int)
    case none
    
    public init(integerLiteral value: Int) {
        self = .offset(value)
    }
    
    public init(nilLiteral: Void) {
        self = .none
    }
}

public protocol SpecifiesPaginationCursor {
    var paginationCursor: PaginationCursor? { get set }
}
