//
// Copyright (c) Vatsal Manot
//

import CombineX
import Foundation
import SwiftUIX

/// A button that triggers a `URLRequest`.
public struct URLRequestButton<Label: View>: View {
    private let request: URLRequest
    private let completion: (URLRequest.Result) -> ()
    private let label: Label
    
    public init(
        request: URLRequest,
        completion: @escaping (URLRequest.Result) -> (),
        @ViewBuilder label: () -> Label
    ) {
        self.request = request
        self.completion = completion
        self.label = label()
    }
    
    public var body: some View {
        RequestButton(
            request: request,
            session: .init(URLSession.shared),
            completion: completion,
            label: { self.label }
        )
    }
}
