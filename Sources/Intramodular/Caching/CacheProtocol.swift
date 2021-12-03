//
// Copyright (c) Vatsal Manot
//

import Foundation
import Merge
import Swallow

public protocol CacheProtocol {
    associatedtype Key: Hashable
    associatedtype Value
    
    func cache(_ value: Value, forKey key: Key) -> AnySingleOutputPublisher<Void, Error>
    func deache(forKey key: Key) -> AnySingleOutputPublisher<Value, Error>
    func decacheInMemoryValue(forKey key: Key) throws -> Value?
    
    @discardableResult
    func removeCachedValue(forKey key: Key) -> AnySingleOutputPublisher<Void, Error>
    func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error>
}

// MARK: - Implementation -

extension CacheProtocol {
    public func deache(forKey key: Key) -> AnySingleOutputPublisher<Value, Error> {
        if let value = try? decacheInMemoryValue(forKey: key) {
            return .just(value)
        } else {
            return .failure(Never.Reason.unimplemented)
        }
    }
}

// MARK: - Conformances -

public protocol _NoCacheType: Initiable & CacheProtocol {
    
}

public final class NoCache<Key: Hashable, Value>: _NoCacheType {
    public init() {
        
    }
    
    public func cache(_ value: Value, forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        AnySingleOutputPublisher<Void, Error>.just(())
    }
    
    public func decacheInMemoryValue(forKey key: Key) throws -> Value? {
        return nil
    }
    
    public func removeCachedValue(forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        AnySingleOutputPublisher<Void, Error>.just(())
    }
    
    public func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error> {
        AnySingleOutputPublisher<Void, Error>.just(())
    }
}

// MARK: - Type Erasure -

public final class AnyCache<Key: Hashable, Value>: CacheProtocol {
    private struct Implementation {
        let cacheValue: (Value, Key) -> AnySingleOutputPublisher<Void, Error>
        let decacheValueForKey: (Key) -> AnySingleOutputPublisher<Value, Error>
        let decacheInMemoryValueForKey: (Key) throws -> Value?
        let removeCachedValueForKey: (Key) -> AnySingleOutputPublisher<Void, Error>
        let removeAllCachedValues: () -> AnySingleOutputPublisher<Void, Error>
    }
    
    private let implementation: Implementation

    public init<Cache: CacheProtocol>(_ cache: Cache) where Cache.Key == Key, Cache.Value == Value {
        self.implementation = Implementation(
            cacheValue: cache.cache,
            decacheValueForKey: cache.deache,
            decacheInMemoryValueForKey: cache.decacheInMemoryValue,
            removeCachedValueForKey: cache.removeCachedValue,
            removeAllCachedValues: cache.removeAllCachedValues
        )
    }
    
    public func cache(_ value: Value, forKey key: Key) -> AnySingleOutputPublisher<Void, Error> {
        self.implementation.cacheValue(value, key)
    }
    
    public func decache(forKey key: Key) -> AnySingleOutputPublisher<Value, Error>{
        self.implementation.decacheValueForKey(key)
    }
    
    public func decacheInMemoryValue(forKey key: Key) throws -> Value?{
        try self.implementation.decacheInMemoryValueForKey(key)
    }
    
    public func removeCachedValue(forKey key: Key) -> AnySingleOutputPublisher<Void, Error>{
        self.implementation.removeCachedValueForKey(key)
    }
    
    public func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error>{
        self.implementation.removeAllCachedValues()
    }
}
