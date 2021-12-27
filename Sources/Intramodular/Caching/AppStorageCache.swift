//
// Copyright (c) Vatsal Manot
//

import FoundationX
import Merge
import Swallow

/// This class is a NSUserDefaults cache level. It has a configurable domain name so that multiple levels can be included in the same sandboxed app.
public final class AppStorageCache: KeyedCodingCache {
    private let userDefaults: UserDefaults
    private let domainName: String
    private let coder: TopLevelDataCoder
    
    private var inMemoryDomainData: [String: Data]?
    
    private var domainData: [String: Data] {
        get {
            if let internalDomain = inMemoryDomainData {
                return internalDomain
            } else {
                let fetchedDomain = (userDefaults.persistentDomain(forName: domainName) as? [String: Data]) ?? [:]
                
                inMemoryDomainData = fetchedDomain
                
                return fetchedDomain
            }
        } set {
            if newValue.isEmpty {
                userDefaults.removePersistentDomain(forName: domainName)
            } else {
                userDefaults.setPersistentDomain(newValue, forName: domainName)
            }
            
            inMemoryDomainData = newValue
        }
    }

    public init(domainName: String, coder: TopLevelDataCoder) {
        self.userDefaults = .standard
        self.domainName = domainName
        self.coder = coder
    }
    
    public func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error> {
        do {
            domainData[key.stringValue] = try coder.encode(value)
            
            return .just(())
        } catch {
            return .failure(error)
        }
    }
    
    public func decache<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) -> AnySingleOutputPublisher<T?, Error> {
        do {
            return .just(try decacheInMemoryValue(type, forKey: key))
        } catch {
            return .failure(error)
        }
    }
    
    public func decacheInMemoryValue(forKey key: AnyCodingKey) throws -> AnyCodable? {
        guard let data = domainData[key.stringValue] else {
            return nil
        }
        
        return try coder.decode(AnyCodable.self, from: data)
    }
    
    public func decacheInMemoryValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) throws -> T? {
        guard let data = domainData[key.stringValue] else {
            return nil
        }
        
        return try coder.decode(T.self, from: data)
    }
    
    public func removeCachedValue(forKey key: AnyCodingKey) -> AnySingleOutputPublisher<Void, Error> {
        domainData[key.stringValue] = nil
        
        return .just(())
    }
    
    public func removeAllCachedValues() -> AnySingleOutputPublisher<Void, Error> {
        domainData = [:]
        
        return .just(())
    }
}
