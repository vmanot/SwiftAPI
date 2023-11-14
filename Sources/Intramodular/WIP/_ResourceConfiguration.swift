//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

public struct _ResourceConfiguration<Value> {
    public enum CachePolicy: String, Codable, Hashable {
        case reloadIgnoringLocalCacheData
        case returnCacheDataElseLoad
        case returnCacheDataThenLoad
        case returnCacheDataDontLoad
        
        var returnsCacheData: Bool {
            switch self {
                case .reloadIgnoringLocalCacheData:
                    return false
                case .returnCacheDataElseLoad:
                    return true
                case .returnCacheDataThenLoad:
                    return true
                case .returnCacheDataDontLoad:
                    return true
            }
        }
    }
    
    public var persistentIdentifier: AnyCodingKey?
    public var cachePolicy: CachePolicy = .reloadIgnoringLocalCacheData
}
