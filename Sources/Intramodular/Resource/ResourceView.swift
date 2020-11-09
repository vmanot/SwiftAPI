//
// Copyright (c) Vatsal Manot
//

import SwiftUIX
import SwiftUI

/// A view that wraps around a resource.
public struct ResourceView<Resource, Placeholder: View, Success: View, Failure: View>: View {
    private let placeholder: () -> Placeholder
    private let successView: (Resource) -> Success
    private let failureView: (Error) -> Failure
    
    private let value: Result<Resource, Error>?
    
    public var body: some View {
        Group {
            value.ifSome { result in
                ResultView(result, success: successView, failure: failureView)
            }.else {
                placeholder()
            }
        }
    }
}

extension ResourceView {
    public init?<Repository, GetEndpoint, SetEndpoint>(
        _ resource: RESTfulResourceAccessor<Resource, Repository, GetEndpoint, SetEndpoint>,
        success: @escaping (Resource) -> Success,
        failure: @escaping (Error) -> Failure,
        placeholder: @escaping () -> Placeholder
    ) {
        self.value = Result(resource: resource)
        self.placeholder = placeholder
        self.successView = success
        self.failureView = failure
    }
}
