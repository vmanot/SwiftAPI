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
                ResultView(result, successView: successView, failureView: failureView)
            }.else {
                placeholder()
            }
        }
    }
}

extension ResourceView {
    public init?<Container, Root, GetEndpoint, SetEndpoint>(
        _ resource: RESTfulResourceAccessor<Resource, Container, Root, GetEndpoint, SetEndpoint>,
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
