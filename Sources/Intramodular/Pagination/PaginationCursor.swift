//
// Copyright (c) Vatsal Manot
//

#if canImport(CloudKit)
import CloudKit
#endif
import Compute
import FoundationX
import Swallow

public enum PaginationCursor: Hashable {
    public enum CursorType: String, Codable {
        case data = "data"
        case string = "string"
        case offset = "offset"
        case pageNumber = "pageNumber"
        case cloudKitQueryCursor = "cloudKitQueryCursor"
        case url = "url"
        case value = "value"
    }
    
    case data(Data)
    case string(String)
    case offset(Int)
    case pageNumber(Int)
    #if canImport(CloudKit)
    case cloudKitQueryCursor(CKQueryOperation.Cursor)
    #endif
    case url(URL)
    case value(AnyCodable)
}

extension PaginationCursor {
    public var offsetValue: Int? {
        guard case let .offset(value) = self else {
            return nil
        }
        
        return value
    }
    
    public func getOffsetValue() throws -> Int {
        try offsetValue.unwrap()
    }
    
    public var stringValue: String? {
        guard case let .string(value) = self else {
            return nil
        }
        
        return value
    }
    
    public var urlValue: URL? {
        guard case let .url(value) = self else {
            return nil
        }
        
        return value
    }
}

// MARK: - Conformances

extension PaginationCursor: Codable {
    public enum CodingKeys: CodingKey {
        case type
        case value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try container.decode(CursorType.self, forKey: .value)
        
        switch type {
            case .data:
                self = try .data(container.decode(Data.self, forKey: .value))
            case .string:
                self = try .string(container.decode(String.self, forKey: .value))
            case .offset:
                self = try .offset(container.decode(Int.self, forKey: .value))
            case .pageNumber:
                self = try .pageNumber(container.decode(Int.self, forKey: .value))
            #if canImport(CloudKit)
            case .cloudKitQueryCursor:
                self = try .cloudKitQueryCursor(CKQueryOperation.Cursor.unarchiveUsingKeyedUnarchiver(from: container.decode(Data.self, forKey: .value)))
            #endif
            case .url:
                self = try .url(container.decode(URL.self, forKey: .value))
            case .value:
                self = try .value(container.decode(AnyCodable.self, forKey: .value))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
            case .data(let data):
                try container.encode(CursorType.data, forKey: .type)
                try container.encode(data, forKey: .value)
            case .string(let string):
                try container.encode(CursorType.string, forKey: .type)
                try container.encode(string, forKey: .value)
            case .offset(let offset):
                try container.encode(CursorType.offset, forKey: .type)
                try container.encode(offset, forKey: .value)
            case .pageNumber(let number):
                try container.encode(CursorType.pageNumber, forKey: .type)
                try container.encode(number, forKey: .value)
            #if canImport(CloudKit)
            case .cloudKitQueryCursor(let cursor):
                try container.encode(CursorType.cloudKitQueryCursor, forKey: .type)
                try container.encode(try cursor.archiveUsingKeyedArchiver(), forKey: .value)
            #endif
            case .url(let url):
                try container.encode(CursorType.url, forKey: .type)
                try container.encode(url, forKey: .value)
            case .value:
                throw Never.Reason.unimplemented
        }
    }
}

extension PaginationCursor: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.data, .data):
                return false
            case (.string, .string):
                return false
            case (.offset(let lhsValue), .offset(let rhsValue)):
                return lhsValue < rhsValue
            case (.pageNumber(let lhsValue), .pageNumber(let rhsValue)):
                return lhsValue < rhsValue
            case (.cloudKitQueryCursor, .cloudKitQueryCursor):
                return false
            case (.value, .value):
                return false
            default:
                return false
        }
    }
    
    public static func > (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
            case (.data, .data):
                return false
            case (.string, .string):
                return false
            case (.offset(let lhsValue), .offset(let rhsValue)):
                return lhsValue > rhsValue
            case (.pageNumber(let lhsValue), .pageNumber(let rhsValue)):
                return lhsValue > rhsValue
            case (.cloudKitQueryCursor, .cloudKitQueryCursor):
                return false
            case (.value, .value):
                return false
            default:
                return false
        }
    }
}

// MARK: - Auxiliary

public enum FetchLimit: Codable, ExpressibleByNilLiteral, Hashable {
    case cursor(PaginationCursor)
    case max(Int)
    case none
    
    public var cursorValue: PaginationCursor? {
        guard case let .cursor(value) = self else {
            return nil
        }
        
        return value
    }

    public var maxValue: Int? {
        guard case let .max(value) = self else {
            return nil
        }
        
        return value
    }
    
    public init(nilLiteral: Void) {
        self = .none
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
            case .cursor(let cursor):
                var container = encoder.singleValueContainer()
                
                try container.encode(cursor)
            case .max(let value):
                var container = encoder.singleValueContainer()

                try container.encode(value)
            case .none:
                var container = encoder.singleValueContainer()
                
                try container.encodeNil()
        }
    }
    
    public init(from decoder: Decoder) throws {
        fatalError()
        /*if (try? decoder.decodeSingleValueNil()) ?? false {
         self = .none
         } else {
         self = .cursor(try decoder.decode(single: PaginationCursor.self))
         }*/
    }
}
