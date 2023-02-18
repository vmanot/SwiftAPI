//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public struct AnyKeyedCache<Key: Hashable, Value>: KeyedCache {
    private struct Implementation {
        let cacheValue: (Value, Key) async throws -> Void
        let retrieveValueForKey: (Key) async throws -> Value?
        let retrieveInMemoryValueForKey: (Key) throws -> Value?
        let removeCachedValueForKey: (Key) async throws -> Void
        let removeAllCachedValues: () async throws -> Void
    }
    
    private let implementation: Implementation
    private let codingCacheImplementation: _opaque_AnyCodingKeyedCache?
    
    public init<Cache: KeyedCache>(_ cache: Cache) where Cache.Key == Key, Cache.Value == Value {
        self.implementation = Implementation(
            cacheValue: cache.cache,
            retrieveValueForKey: cache.retrieveValue(forKey:),
            retrieveInMemoryValueForKey: cache.retrieveInMemoryValue,
            removeCachedValueForKey: cache.removeCachedValue,
            removeAllCachedValues: cache.removeAllCachedValues
        )
        self.codingCacheImplementation = nil
    }
    
    public init<Cache: KeyedCodingCache>(
        _ cache: Cache,
        valueType: Value.Type
    ) where Key: StringConvertible, Value: Codable & Sendable {
        self.implementation = Implementation(
            cacheValue: {
                try await cache.cache($0, forKey: .init(stringValue: $1.stringValue))
            },
            retrieveValueForKey: {
                try await cache.retrieveValue(valueType, forKey: .init(stringValue: $0.stringValue))
            },
            retrieveInMemoryValueForKey: {
                try cache.retrieveInMemoryValue(valueType, forKey: .init(stringValue: $0.stringValue))
            },
            removeCachedValueForKey: {
                try await cache.removeCachedValue(forKey: .init(stringValue: $0.stringValue))
            },
            removeAllCachedValues: {
                try await cache.removeAllCachedValues()
            }
        )
        self.codingCacheImplementation = _AnyCodingKeyedCache(base: cache, keyPrefix: nil)
    }
    
    public init<Cache: KeyedCodingCache>(
        _ cache: Cache,
        keyPrefix: String,
        valueType: Value.Type
    ) where Key == AnyCodingKey, Value: Codable & Sendable {
        self.implementation = Implementation(
            cacheValue: {
                try await cache.cache($0, forKey: .init(stringValue: keyPrefix + $1.stringValue))
            },
            retrieveValueForKey: {
                try await cache.retrieveValue(valueType, forKey: .init(stringValue: keyPrefix + $0.stringValue))
            },
            retrieveInMemoryValueForKey: {
                try cache.retrieveInMemoryValue(valueType, forKey: .init(stringValue: keyPrefix + $0.stringValue))
            },
            removeCachedValueForKey: {
                try await cache.removeCachedValue(forKey: .init(stringValue: keyPrefix + $0.stringValue))
            },
            removeAllCachedValues: {
                TODO.unimplemented
            }
        )
        self.codingCacheImplementation = _AnyCodingKeyedCache(base: cache, keyPrefix: keyPrefix)
    }
    
    public func cache(_ value: Value, forKey key: Key) async throws {
        try await implementation.cacheValue(value, key)
    }
    
    public func retrieveValue(forKey key: Key) async throws -> Value? {
        try await implementation.retrieveValueForKey(key)
    }
    
    public func retrieveInMemoryValue(forKey key: Key) throws -> Value? {
        try implementation.retrieveInMemoryValueForKey(key)
    }
    
    public func removeCachedValue(forKey key: Key) async throws {
        try await implementation.removeCachedValueForKey(key)
    }
    
    public func removeAllCachedValues() async throws {
        try await implementation.removeAllCachedValues()
    }
}

extension AnyKeyedCache: KeyedCodingCache where Key == AnyCodingKey, Value == AnyCodable {
    public func cache<T: Encodable>(_ value: T, forKey key: Key) async throws {
        try await codingCacheImplementation.unwrap().cache(value, forKey: key)
    }
    
    public func retrieveValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) async throws -> T? {
        try await codingCacheImplementation.unwrap().retrieveValue(type, forKey: key)
    }
    
    public func retrieveInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        try codingCacheImplementation.unwrap().retrieveInMemoryValue(type, forKey: key)
    }
}

// MARK: - API

extension KeyedCodingCache {
    public func withKeyPrefix(_ prefix: String) -> AnyKeyedCache<AnyCodingKey, AnyCodable> {
        .init(self, keyPrefix: prefix, valueType: AnyCodable.self)
    }
    
    public func code<Key: Hashable & StringConvertible, Value: Codable>(
        _ type: Value.Type
    ) -> AnyKeyedCache<Key, Value> {
        .init(self, valueType: type)
    }
}

// MARK: - Auxiliary

fileprivate protocol _opaque_AnyCodingKeyedCache  {
    func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) async throws
    func retrieveValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) async throws -> T?
    func retrieveInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T?
}

fileprivate struct _AnyCodingKeyedCache<Cache: KeyedCodingCache>: _opaque_AnyCodingKeyedCache {
    let base: Cache
    let keyPrefix: String?
    
    func cache<T: Encodable & Sendable>(
        _ value: T,
        forKey key: AnyCodingKey
    ) async throws {
        try await base.cache(value, forKey: _toPrefixedKey(key))
    }
    
    func retrieveValue<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) async throws -> T? {
        try await base.retrieveValue(type, forKey: _toPrefixedKey(key))
    }
    
    func retrieveInMemoryValue<T: Decodable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) throws -> T? {
        try base.retrieveInMemoryValue(type, forKey: _toPrefixedKey(key))
    }
    
    private func _toPrefixedKey(_ key: AnyCodingKey) -> AnyCodingKey {
        AnyCodingKey(stringValue: (keyPrefix ?? String()) + key.stringValue)
    }
}
