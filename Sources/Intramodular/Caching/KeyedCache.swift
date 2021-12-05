//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public protocol KeyedCache {
    associatedtype Key: Hashable
    associatedtype Value
    
    /// Store a value for the given key.
    ///
    /// - parameter value: The value to store.
    /// - parameter key: The key that the value is associated with.
    /// - returns: A publisher that emits once the caching attempt has finished.
    func cache(_ value: Value, forKey key: Key) -> AnySingleOutputPublisher<Void, Error>
    
    /// Attempt to retrieve a value associated with the given key.
    ///
    /// - parameter key: The key the value is associated with.
    /// - returns: A publisher that emits the associated value if it exists, or an error if decaching failed.
    func decache(forKey key: Key) -> AnySingleOutputPublisher<Value?, Error>
    
    /// Attempt to retrieve an in-memory value associated with the given key.
    ///
    /// This method is meant to provide an inexpensive, fast path to decaching if available. A `nil` result does not necessarily mean that no cahed value exists for the given key, only that a value does not exist in-memory.
    ///
    /// - parameter key: The key the value is associated with.
    /// - returns: The value associated with the given key, if it exists in-memory.
    /// - throws: An error if the operation operation fails.
    /// - complexity: O(1)
    func decacheInMemoryValue(forKey key: Key) throws -> Value?
    
    @discardableResult
    func removeCachedValue(forKey key: Key) -> AnySingleOutputPublisher<Void, Error>
    @discardableResult
    func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error>
}

public protocol KeyedCodingCache: KeyedCache where Key == AnyCodingKey, Value == AnyCodable {
    func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error>
    func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error>
    func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T?
}

// MARK: - Implementation -

extension KeyedCache {
    public func decache(forKey key: Key) -> AnySingleOutputPublisher<Value?, Error> {
        if let value = try? decacheInMemoryValue(forKey: key) {
            return .just(value)
        } else {
            return .failure(Never.Reason.unimplemented)
        }
    }
}

// MARK: - Conformances -

public final class EmptyKeyedCache<Key: Hashable, Value>: Initiable & KeyedCache {
    public init() {
        
    }
    
    public func cache(_ value: Value, forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        .just(())
    }
    
    public func decacheInMemoryValue(forKey key: Key) throws -> Value? {
        nil
    }
    
    public func removeCachedValue(forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        .just(())
    }
    
    public func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error> {
        .just(())
    }
}

extension EmptyKeyedCache: KeyedCodingCache where Key == AnyCodingKey, Value == AnyCodable {
    public func cache<T: Encodable>(_ value: T, forKey key: Key) -> AnySingleOutputPublisher<Void, Error>  {
        .just(())
    }
    
    public func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error> {
        .just(nil)
    }
    
    public func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T?  {
        nil
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
