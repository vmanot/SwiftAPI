//
// Copyright (c) Vatsal Manot
//

import CombineX
import Foundation
import ObjectiveC
import Swift

extension URLRequest: Request {
    public typealias Response = (data: Data, response: URLResponse)
    public typealias Error = URLError
}

extension URLSession: RequestSession {
    public typealias Request = URLRequest
    
    public func task(with request: Request) -> DataTaskPublisher {
        dataTaskPublisher(for: request)
    }
}
