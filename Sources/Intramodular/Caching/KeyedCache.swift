//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Merge
import Swallow

/// A keyed cache suitable for caching and retrieving values.
public protocol KeyedCache<Key, Value> {
    associatedtype Key: Hashable
    associatedtype Value: Sendable
    
    /// Store a value for the given key.
    ///
    /// - parameter value: The value to store.
    /// - parameter key: The key that the value is associated with.
    /// - returns: A publisher that emits once the caching attempt has finished.
    func cache(_ value: Value, forKey key: Key) async throws
    
    /// Attempt to retrieve a value associated with the given key.
    ///
    /// - parameter key: The key the value is associated with.
    /// - returns: A publisher that emits the associated value if it exists, or an error if decaching failed.
    func retrieveValue(forKey key: Key) async throws -> Value?
    
    /// Attempt to retrieve an in-memory value associated with the given key.
    ///
    /// This method is meant to provide an inexpensive, fast path to decaching if available. A `nil` result does not necessarily mean that no cahed value exists for the given key, only that a value does not exist in-memory.
    ///
    /// - parameter key: The key the value is associated with.
    /// - returns: The value associated with the given key, if it exists in-memory.
    /// - throws: An error if the operation operation fails.
    /// - complexity: O(1)
    func retrieveInMemoryValue(forKey key: Key) throws -> Value?
    
    func removeCachedValue(forKey key: Key) async throws
    func removeAllCachedValues() async throws
}

// MARK: - Implementation

extension KeyedCache {
    public func retrieveValue(forKey key: Key) async throws -> Value? {
        if let value = try? retrieveInMemoryValue(forKey: key) {
            return value
        } else {
            throw Never.Reason.unimplemented
        }
    }
}

// MARK: - Conformances

extension _NSCacheWithExpiry: KeyedCache {
    
}

/// A keyed-cache where every option is a no-op.
///
/// Value retrieval functions will yield a `nil`.
public final class EmptyKeyedCache<Key: Hashable, Value>: Initiable & KeyedCache {
    public init() {
        
    }
    
    public func cache(_ value: Value, forKey key: Key) async throws {
        
    }
    
    public func retrieveInMemoryValue(forKey key: Key) throws -> Value? {
        nil
    }
    
    public func removeCachedValue(forKey key: Key) async throws {
        
    }
    
    public func removeAllCachedValues() async throws {
        
    }
}

extension EmptyKeyedCache: KeyedCodingCache where Key == AnyCodingKey, Value == AnyCodable {
    public func cache<T: Encodable>(_ value: T, forKey key: Key) async throws  {
        
    }
    
    public func retrieveValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) async throws -> T? {
        nil
    }
    
    public func retrieveInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T?  {
        nil
    }
}
