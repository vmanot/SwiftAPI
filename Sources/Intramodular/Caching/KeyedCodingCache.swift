//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public protocol KeyedCodingCache: KeyedCache where Key == AnyCodingKey, Value == AnyCodable {
    func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error>
    func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error>
    func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T?
}

// MARK: - API -

extension KeyedCodingCache {
    public func cache<T>(_ value: T, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error> {
        do {
            return try cast(value, to: Encodable.self)._cache(into: self, forKey: key)
        } catch {
            return .failure(error)
        }
    }
    
    public func decache<T>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error> {
        do {
            return try cast(type, to: Decodable.Type.self)._decache(from: self, forKey: key).tryMap({ try cast($0, to: T.self) }).eraseToAnySingleOutputPublisher()
        } catch {
            return .failure(error)
        }
    }
    
    public func decacheInMemoryValue<T>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T? {
        try cast(cast(type, to: Decodable.Type.self)._decacheInMemoryValue(from: self, forKey: key), to: T.self)
    }
}

// MARK: - Auxiliary Implementation -

extension Decodable {
    static func _decache<Cache: KeyedCodingCache>(from cache: Cache, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Decodable?, Error> {
        cache.decache(self, forKey: key).map({ $0 as Decodable? }).eraseToAnySingleOutputPublisher()
    }
    
    static func _decacheInMemoryValue<Cache: KeyedCodingCache>(from cache: Cache, forKey key: AnyCodingKey) throws -> Decodable? {
        try cache.decacheInMemoryValue(self, forKey: key)
    }
}

extension Encodable {
    func _cache<Cache: KeyedCodingCache>(into cache: Cache, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error> {
        cache.cache(self, forKey: key)
    }
}
