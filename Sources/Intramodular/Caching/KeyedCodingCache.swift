//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public protocol KeyedCodingCache: KeyedCache where Key == AnyCodingKey, Value == AnyCodable {
    func cache<T: Encodable & Sendable>(
        _ value: T,
        forKey key: AnyCodingKey
    ) async throws
    func retrieveValue<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) async throws -> T?
    func retrieveInMemoryValue<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) throws -> T?
}

// MARK: - API

extension KeyedCodingCache {
    public func cache<T: Sendable>(
        _ value: T,
        forKey key: AnyCodingKey
    ) async throws {
        try await cast(value, to: (Encodable & Sendable).self)._cache(into: self, forKey: key)
    }
    
    public func decache<T: Sendable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) async throws -> T? {
        let retrievedValue = try await cast(type, to: (Decodable & Sendable).Type.self)._retrieveValue(from: self, forKey: key)
        
        return try cast(retrievedValue, to: T.self)
    }
    
    public func retrieveInMemoryValue<T: Sendable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) throws -> T? {
        try cast(cast(type, to: Decodable.Type.self)._retrieveInMemoryValue(from: self, forKey: key), to: T.self)
    }
}

// MARK: - Auxiliary

extension Decodable where Self: Sendable {
    static func _retrieveValue<Cache: KeyedCodingCache>(
        from cache: Cache,
        forKey key: AnyCodingKey
    ) async throws -> Decodable? {
        try await cache.retrieveValue(self, forKey: key)
    }
    
    static func _retrieveInMemoryValue<Cache: KeyedCodingCache>(from cache: Cache, forKey key: AnyCodingKey) throws -> Decodable? {
        try cache.retrieveInMemoryValue(self, forKey: key)
    }
}

extension Encodable where Self: Sendable {
    func _cache<Cache: KeyedCodingCache>(into cache: Cache, forKey key: AnyCodingKey) async throws {
        try await cache.cache(self, forKey: key)
    }
}
