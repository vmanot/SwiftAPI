//
// Copyright (c) Vatsal Manot
//

import Diagnostics
import Merge
import Foundation
import Swift

extension URLRequest: Request {
    public typealias Response = (data: Data, response: URLResponse)
    public typealias Error = URLError
}

extension URLSession: RequestSession {
    public typealias Request = URLRequest
    
    public func task(
        with request: Request
    ) -> AnyTask<DataTaskPublisher.Output, DataTaskPublisher.Failure> {
        dataTaskPublisher(for: request).convertToTask()
    }
}

extension URLError: _ErrorX {
    public var traits: ErrorTraits {
        [.domain(.networking)]
    }
}
