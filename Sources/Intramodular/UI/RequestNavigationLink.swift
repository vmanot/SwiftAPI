//
// Copyright (c) Vatsal Manot
//

import CombineX
import SwiftUIX

public struct RequestNavigationLink<R: Request, Destination: View, Label: View>: View {
    private let request: R
    private let destination: () -> Destination
    private let label: Label
    
    @EnvironmentObjectOrState private var session: AnyRequestSession<R>
    
    @State var isActive: Bool = false
    
    public init(
        request: R,
        session: AnyRequestSession<R>,
        destination: Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.request = request
        self._session = .init(wrappedValue: session)
        self.destination = { destination }
        self.label = label()
    }
    
    public init(
        request: R,
        session: AnyRequestSession<R>,
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: () -> Label
    ) {
        self.request = request
        self._session = .init(wrappedValue: session)
        self.destination = destination
        self.label = label()
    }
    
    public var body: some View {
        RequestButton(
            request: request,
            action: { self.isActive = true },
            label: { label }
        ).navigate(isActive: $isActive) {
            self.destination()
        }
    }
}
