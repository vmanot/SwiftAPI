//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public protocol KeyedCodingCache: KeyedCache where Key == AnyCodingKey, Value == AnyCodable {
    func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) async throws
    func retrieveValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) async throws -> T?
    func retrieveInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T?
}

// MARK: - API -

extension KeyedCodingCache {
    public func cache<T>(_ value: T, forKey key: AnyCodingKey) async throws {
        try await cast(value, to: Encodable.self)._cache(into: self, forKey: key)
    }
    
    public func decache<T>(_ type: T.Type, forKey key: AnyCodingKey) async throws -> T? {
        try await cast(cast(type, to: Decodable.Type.self)._retrieveValue(from: self, forKey: key), to: T.self)
    }
    
    public func retrieveInMemoryValue<T>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T? {
        try cast(cast(type, to: Decodable.Type.self)._retrieveInMemoryValue(from: self, forKey: key), to: T.self)
    }
}

// MARK: - Auxiliary -

extension Decodable {
    static func _retrieveValue<Cache: KeyedCodingCache>(from cache: Cache, forKey key: AnyCodingKey) async throws -> Decodable? {
        try await cache.retrieveValue(self, forKey: key)
    }
    
    static func _retrieveInMemoryValue<Cache: KeyedCodingCache>(from cache: Cache, forKey key: AnyCodingKey) throws -> Decodable? {
        try cache.retrieveInMemoryValue(self, forKey: key)
    }
}

extension Encodable {
    func _cache<Cache: KeyedCodingCache>(into cache: Cache, forKey key: AnyCodingKey) async throws {
        try await cache.cache(self, forKey: key)
    }
}
