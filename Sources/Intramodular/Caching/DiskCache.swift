//
// Copyright (c) Vatsal Manot
//

import CryptoKit
import Diagnostics
import FoundationX
import Merge
import os
import Swallow

/// A cache that reads/writes values from the disk, translating keys to file names.
///
/// Based on https://github.com/spring-media/Carlos.
@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
public final class DiskCache<Key: Hashable & StringConvertible, Value: Codable & Sendable>: @unchecked Sendable {
    public enum CacheError: Error {
        case writeFailed(Error)
    }
    
    private let logger = os.Logger(subsystem: "com.vmanot.API", category: "DiskCache")
    @_UncheckedSendable
    private var queue = DispatchQueue(label: DiskCache.self)
    
    public static var defaultLocation: URL {
        URL(
            fileURLWithPath: NSSearchPathForDirectoriesInDomains(
                FileManager.SearchPathDirectory.cachesDirectory,
                FileManager.SearchPathDomainMask.userDomainMask,
                true
            )[0]
        ).appendingPathComponent("com.vmanot.API.DiskCache.default")
    }
    
    private let location: URL
    private let coder: any TopLevelDataCoder
    private var size: UInt64 = 0
    private let fileManager: FileManager
    
    /// The capacity of the cache
    public var capacity: UInt64 = 0 {
        didSet {
            queue.async {
                self.controlCapacity()
            }
        }
    }
    
    public init(
        location: URL = DiskCache<AnyCodingKey, AnyCodable>.defaultLocation,
        coder: any TopLevelDataCoder,
        capacity: UInt64 = 100 * 1024 * 1024,
        fileManager: FileManager = FileManager.default
    ) {
        self.location = location
        self.coder = coder
        self.fileManager = fileManager
        self.capacity = capacity
        
        _ = try? fileManager.createDirectory(atPath: location.path, withIntermediateDirectories: true, attributes: [:])
        
        queue.async {
            do {
                try self.calculateSize()
                
                self.controlCapacity()
            } catch {
                self.logger.error(error)
            }
        }
    }
    
    private func cache<T: Encodable & Sendable>(_ value: T, forKey key: String) async throws {
        try await Just((value, key))
            .setFailureType(to: Error.self)
            .subscribe(on: queue)
            .flatMap { [weak self] payload -> AnySingleOutputPublisher<Void, Error> in
                return self!.setDataSync(payload.0, key: payload.1)
            }
            .output()
    }
    
    private func retrieveValue<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: String
    ) async throws -> T? {
        try await Future<T?, Error> { [weak self] attemptToFulfill in
            do {
                let `self` = try self.unwrap()
                let url = self.urlForKey(key)
                
                guard self.fileManager.fileExists(at: url) else {
                    attemptToFulfill(.success(nil))
                    
                    return
                }
                
                let data = try Data(contentsOf: url)
                let value = try self.coder.decode(type, from: data)
                
                attemptToFulfill(.success(value))
                
                _ = self.updateDiskAccessDateAtPath(url.path)
            } catch {
                attemptToFulfill(.failure(error))
            }
        }
        .subscribe(on: queue)
        .eraseToAnySingleOutputPublisher()
        .output()
    }
    
    private func removeCachedValue(forKey key: String) async throws {
        try await Deferred {
            Future<Void, Error> { [weak self] attemptToFulfill in
                do {
                    let `self` = try self.unwrap()
                    
                    try self.fileManager.removeItem(at: self.urlForKey(key))
                    
                    try self.calculateSize()
                    
                    attemptToFulfill(.success(()))
                } catch {
                    attemptToFulfill(.failure(error))
                }
            }
        }
        .subscribe(on: queue)
        .eraseToAnySingleOutputPublisher()
        .output()
    }
    
    private func removeDataForKey(_ key: String) {
        queue.async {
            try? self.removeFile(at: self.urlForKey(key))
        }
    }
    
    private func urlForKey(_ key: String) -> URL {
        let md5PathComponent = key.md5Hash
        let strippedMd5PathComponent = stripSpecialCharactersForPath(from: md5PathComponent)
        
        return location.appendingPathComponent(strippedMd5PathComponent)
    }
    
    private func stripSpecialCharactersForPath(from string: String) -> String {
        let okayChars = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLKMNOPQRSTUVWXYZ1234567890")
        
        return string.filter({ okayChars.contains($0) })
    }
    
    private func sizeForFileAtPath(_ filePath: String) -> UInt64 {
        var size: UInt64 = 0
        
        do {
            let attributes: NSDictionary = try fileManager.attributesOfItem(atPath: filePath) as NSDictionary
            size = attributes.fileSize()
        } catch {}
        
        return size
    }
    
    private func calculateSize() throws {
        size = try itemsInDirectory(location).reduce(0) { accumulator, filePath in
            accumulator + sizeForFileAtPath(filePath)
        }
    }
    
    private func controlCapacity() {
        if size > capacity {
            enumerateContentsOfDirectorySortedByAscendingModificationDate(at: location) { (url, stop: inout Bool) in
                try? removeFile(at: url)
                stop = size <= capacity
            }
        }
    }
    
    private func setDataSync<T: Encodable & Sendable>(
        _ data: T,
        key: String
    ) -> AnySingleOutputPublisher<Void, Error> {
        let url = urlForKey(key)
        let path = url.path
        
        let previousSize = sizeForFileAtPath(path)
        
        do {
            let data = try coder.encode(data)
            
            try data.write(to: URL(fileURLWithPath: path), options: .atomicWrite)
            
            _ = updateDiskAccessDateAtPath(path)
            
            let newSize = sizeForFileAtPath(path)
            
            if newSize > previousSize {
                size += newSize - previousSize
                
                controlCapacity()
            } else {
                size -= previousSize - newSize
            }
            
            return .just(())
        } catch {
            logger.error("Failed to write key \(key.stringValue) on the disk cache")
            
            return .failure(CacheError.writeFailed(error))
        }
    }
    
    private func updateDiskAccessDateAtPath(_ path: String) -> Bool {
        var result = false
        
        do {
            try fileManager.setAttributes([FileAttributeKey.modificationDate: Date()], ofItemAtPath: path)
            
            result = true
        } catch {
            
        }
        
        return result
    }
    
    private func removeFile(at url: URL) throws {
        if let attributes: NSDictionary = try fileManager.attributesOfItem(atPath: url.path) as NSDictionary? {
            try fileManager.removeItem(at: url)
            
            size -= attributes.fileSize()
        }
    }
    
    private func itemsInDirectory(_ directory: URL) throws -> [String] {
        var items: [String] = []
        
        items = try fileManager.contentsOfDirectory(atPath: directory.path).map {
            directory.appendingPathComponent($0).path
        }
        
        return items
    }
    
    private func enumerateContentsOfDirectorySortedByAscendingModificationDate(
        at directoryURL: URL,
        usingBlock block: (URL, inout Bool) -> Void
    ) {
        let property = URLResourceKey.contentModificationDateKey
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [property], options: [])
            
            let sortedContents = contents.sorted(by: { URL1, URL2 in
                var value1: AnyObject?
                
                do {
                    try (URL1 as NSURL).getResourceValue(&value1, forKey: property)
                } catch _ {
                    return true
                }
                
                var value2: AnyObject?
                
                do {
                    try (URL2 as NSURL).getResourceValue(&value2, forKey: property)
                } catch _ {
                    return false
                }
                
                if let date1 = value1 as? Date, let date2 = value2 as? Date {
                    return date1.compare(date2) == .orderedAscending
                }
                
                return false
            })
            
            for value in sortedContents {
                var stop = false
                
                block(value, &stop)
                
                if stop {
                    break
                }
            }
        } catch _ {
            
        }
    }
}

// MARK: - Conformances

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
extension DiskCache: KeyedCache {
    public func cache(_ value: Value, forKey key: Key) async throws {
        try await cache(
            AnyEncodable({ try value.encode(to: $0) }),
            forKey: key.stringValue
        )
    }
    
    public func retrieveValue(forKey key: Key) async throws -> Value? {
        try await retrieveValue(Value.self, forKey: key.stringValue)
    }
    
    public func retrieveInMemoryValue(forKey key: Key) throws -> Value? {
        nil
    }
    
    public func removeCachedValue(forKey key: Key) async throws {
        try await removeCachedValue(forKey: key.stringValue)
    }
    
    public func removeAllCachedValues() async throws {
        try await withUnsafeThrowingContinuation { (continuation: UnsafeContinuation<Void, Error>) in
            self.queue.async {
                do {
                    try self.itemsInDirectory(self.location).forEach { filePath in
                        _ = try? self.fileManager.removeItem(atPath: filePath)
                    }
                    try self.calculateSize()
                    
                    continuation.resume(with: .success(()))
                } catch {
                    continuation.resume(with: .failure(error))
                }
            }
        }
    }
}

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
extension DiskCache: KeyedCodingCache where Key == AnyCodingKey, Value == AnyCodable {
    public func cache<T: Encodable & Sendable>(_ value: T, forKey key: Key) async throws  {
        try await cache(value, forKey: key.stringValue)
    }
    
    public func retrieveValue<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: Key
    ) async throws -> T? {
        try await retrieveValue(type, forKey: key.stringValue)
    }
    
    public func retrieveInMemoryValue<T: Decodable & Sendable>(
        _ type: T.Type,
        forKey key: Key
    ) throws -> T? {
        nil
    }
}

// MARK: - Auxiliary

fileprivate extension String {
    var md5Hash: String {
        guard let data = data(using: .utf8) else {
            return self
        }
        
        return Insecure.MD5.hash(data: data)
            .map({ String(format: "%02hhx", $0) })
            .joined()
    }
}
