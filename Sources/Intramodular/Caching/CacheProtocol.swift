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
