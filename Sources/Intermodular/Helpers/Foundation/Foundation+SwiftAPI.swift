//
// Copyright (c) Vatsal Manot
//

import Merge
import Foundation
import Swift

extension URLRequest: SwiftAPI.Request {
    public typealias Response = (data: Data, response: URLResponse)
    public typealias Error = URLError
}

extension URLSession: SwiftAPI.RequestSession {
    public typealias Request = URLRequest
    
    public func task(
        with request: Request
    ) -> AnyTask<DataTaskPublisher.Output, DataTaskPublisher.Failure> {
        dataTaskPublisher(for: request).convertToTask()
    }
}
