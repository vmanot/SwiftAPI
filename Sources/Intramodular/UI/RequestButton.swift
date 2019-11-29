//
// Copyright (c) Vatsal Manot
//

import CombineX
import SwiftUIX

public struct RequestButton<R: Request, Label: View>: View {
    public enum ButtonState {
        case inactive
        case active
        case success
        case failure
    }
    
    private let request: R
    private let completion: (R.Result) -> ()
    private let label: (ButtonState) -> Label
    
    private var canRetry: Bool = true
    
    @State private var didTry: Bool = false
    @State private var state: ButtonState = .inactive
    @State private var cancellable: AnyCancellable?
    
    @EnvironmentObjectOrState private var session: AnyRequestSession<R>
    
    public var body: some View {
        Button(action: run) {
            label(state)
        }
    }
    
    public init(
        request: R,
        session: AnyRequestSession<R>,
        completion: @escaping (R.Result) -> () = { _ in },
        @ViewBuilder label: () -> Label
    ) {
        let _label = label()
        
        self.request = request
        self._session = .init(wrappedValue: session)
        self.completion = completion
        self.label = { _ in _label }
    }
    
    public init(
        request: R,
        completion: @escaping (R.Result) -> () = { _ in },
        @ViewBuilder label: () -> Label
    ) {
        let _label = label()
        
        self.request = request
        self.completion = completion
        self.label = { _ in _label }
    }
    
    public init(
        request: R,
        action: @escaping () -> (),
        @ViewBuilder label: () -> Label
    ) {
        let _label = label()
        
        self.request = request
        self.completion = { _ in action() }
        self.label = { _ in _label }
    }
    
    func trigger() {
        if !canRetry && didTry {
            return
        }
        
        cancel()
        run()
    }
    
    func run() {
        cancellable = session
            .task(with: request)
            .receiveOnMain()
            .sinkResult(complete)
        
        cancellable?.store(in: &session.cancellables)
        
        state = .active
    }
    
    func cancel() {
        guard cancellable != nil else {
            return
        }
        
        cancellable?.cancel()
        cancellable = nil
        
        state = .inactive
    }
    
    func complete(_ result: R.Result) {
        didTry = true
        
        completion(result)
        
        switch result {
            case .success:
                state = .success
            case .failure:
                state = .failure
        }
    }
}

extension RequestButton {
    public func canRetry(_ canRetry: Bool) -> Self {
        then({ $0.canRetry = canRetry })
    }
}
