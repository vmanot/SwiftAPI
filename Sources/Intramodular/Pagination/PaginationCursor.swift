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
    public enum CursorType {
        case data
        case string
        case offset
        case cloudKitQueryCursor
        case value
    }
    
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

// MARK: - Conformances -

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

public enum FetchLimit: Codable, ExpressibleByIntegerLiteral, ExpressibleByNilLiteral, Hashable {
    case cursor(PaginationCursor)
    case none
    
    public init(integerLiteral value: Int) {
        self = .cursor(.offset(value))
    }
    
    public init(nilLiteral: Void) {
        self = .none
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
            case .cursor(let cursor):
                try encoder.encode(single: cursor)
            case .none:
                try encoder.encodeSingleNil()
        }
    }
    
    public init(from decoder: Decoder) throws {
        if (try? decoder.decodeSingleValueNil()) ?? false {
            self = .none
        } else {
            self = .cursor(try decoder.decode(single: PaginationCursor.self))
        }
    }
    
}

public protocol SpecifiesPaginationCursor {
    var paginationCursor: PaginationCursor? { get set }
}
