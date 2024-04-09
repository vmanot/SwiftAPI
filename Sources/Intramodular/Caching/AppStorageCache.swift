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
    private let coder: any TopLevelDataCoder
    
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

    public init(
        domainName: String,
        coder: any TopLevelDataCoder
    ) {
        self.userDefaults = .standard
        self.domainName = domainName
        self.coder = coder
    }
    
    public func cache<T: Encodable>(_ value: T, forKey key: AnyCodingKey) async throws {
        domainData[key.stringValue] = try coder.encode(value)
    }
    
    public func retrieveValue<T: Decodable>(_ type: T.Type, forKey key: AnyCodingKey) async throws -> T? {
        try retrieveInMemoryValue(type, forKey: key)
    }
    
    public func retrieveInMemoryValue(forKey key: AnyCodingKey) throws -> AnyCodable? {
        guard let data = domainData[key.stringValue] else {
            return nil
        }
        
        return try coder.decode(AnyCodable.self, from: data)
    }
    
    public func retrieveInMemoryValue<T: Decodable>(
        _ type: T.Type,
        forKey key: AnyCodingKey
    ) throws -> T? {
        guard let data = domainData[key.stringValue] else {
            return nil
        }
        
        return try coder.decode(T.self, from: data)
    }
    
    public func removeCachedValue(forKey key: AnyCodingKey) async throws {
        domainData[key.stringValue] = nil
    }
    
    public func removeAllCachedValues() async throws {
        domainData = [:]
    }
}
