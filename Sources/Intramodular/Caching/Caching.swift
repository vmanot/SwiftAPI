//
// Copyright (c) Vatsal Manot
//

import Foundation
import Swallow

public protocol Caching {
    associatedtype Cache: CacheProtocol
    
    var cache: Cache { get }
}

// MARK: - Implementation -

private var Caching_cache_objcAssociationKey: UInt = 0

extension Caching where Self: AnyObject, Cache: Initiable {
    public var cache: Cache {
        if let result = objc_getAssociatedObject(self, &Caching_cache_objcAssociationKey) as? Cache {
            return result
        } else {
            let result = Cache()
            
            objc_setAssociatedObject(self, &Caching_cache_objcAssociationKey, result, .OBJC_ASSOCIATION_RETAIN)
            
            return result
        }
    }
}
