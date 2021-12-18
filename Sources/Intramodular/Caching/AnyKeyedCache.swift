//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public struct AnyKeyedCache<Key: Hashable, Value>: KeyedCache {
    private struct Implementation {
        let cacheValue: (Value, Key) -> AnySingleOutputPublisher<Void, Error>
        let decacheValueForKey: (Key) -> AnySingleOutputPublisher<Value?, Error>
        let decacheInMemoryValueForKey: (Key) throws -> Value?
        let removeCachedValueForKey: (Key) -> AnySingleOutputPublisher<Void, Error>
        let removeAllCachedValues: () -> AnySingleOutputPublisher<Void, Error>
    }
    
    private let implementation: Implementation
    private let codingCacheImplementation: _opaque_AnyCodingCacheBox?
    
    public init<Cache: KeyedCache>(_ cache: Cache) where Cache.Key == Key, Cache.Value == Value {
        self.implementation = Implementation(
            cacheValue: cache.cache,
            decacheValueForKey: cache.decache,
            decacheInMemoryValueForKey: cache.decacheInMemoryValue,
            removeCachedValueForKey: cache.removeCachedValue,
            removeAllCachedValues: cache.removeAllCachedValues
        )
        self.codingCacheImplementation = nil
    }
    
    public init<Cache: KeyedCodingCache>(
        _ cache: Cache,
        type: Value.Type
    ) where Key: StringConvertible, Value: Codable {
        self.implementation = Implementation(
            cacheValue: { cache.cache($0, forKey: .init(stringValue: $1.stringValue)) },
            decacheValueForKey: { cache.decache(type, forKey: .init(stringValue: $0.stringValue)) },
            decacheInMemoryValueForKey: { try cache.decacheInMemoryValue(type, forKey: .init(stringValue: $0.stringValue)) },
            removeCachedValueForKey: { cache.removeCachedValue(forKey: .init(stringValue: $0.stringValue)) },
            removeAllCachedValues: { cache.removeAllCachedValues() }
        )
        self.codingCacheImplementation = _AnyCodingCacheBox(base: cache)
    }
    
    public func cache(_ value: Value, forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        implementation.cacheValue(value, key)
    }
    
    public func decache(forKey key: Key) -> AnySingleOutputPublisher<Value?, Error> {
        implementation.decacheValueForKey(key)
    }
    
    public func decacheInMemoryValue(forKey key: Key) throws -> Value? {
        try implementation.decacheInMemoryValueForKey(key)
    }
    
    public func removeCachedValue(forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        implementation.removeCachedValueForKey(key)
    }
    
    public func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error> {
        implementation.removeAllCachedValues()
    }
}

extension AnyKeyedCache: KeyedCodingCache where Key == AnyCodingKey, Value == AnyCodable {
    public func cache<T: Encodable>(_ value: T, forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        do {
            return try codingCacheImplementation.unwrap().cache(value, forKey: key)
        } catch {
            return .failure(error)
        }
    }
    
    public func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error> {
        do {
            return try codingCacheImplementation.unwrap().decache(type, forKey: key)
        } catch {
            return .failure(error)
        }
    }
    
    public func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T? {
        try codingCacheImplementation.unwrap().decacheInMemoryValue(type, forKey: key)
    }
}

// MARK: - API -

extension KeyedCodingCache {
    public func code<Key: Hashable & StringConvertible, Value: Codable>(
        _ type: Value.Type
    ) -> AnyKeyedCache<Key, Value> {
        .init(self, type: type)
    }
}

// MARK: - Auxiliary Implementation -

fileprivate protocol _opaque_AnyCodingCacheBox  {
    func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error>
    func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error>
    func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T?
}

fileprivate struct _AnyCodingCacheBox<Cache: KeyedCodingCache>: _opaque_AnyCodingCacheBox {
    let base: Cache
    
    func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error> {
        base.cache(value, forKey: key)
    }
    
    func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error> {
        base.decache(type, forKey: key)
    }
    
    func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T? {
        try base.decacheInMemoryValue(type, forKey: key)
    }
}
