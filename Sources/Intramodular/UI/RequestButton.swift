//
// Copyright (c) Vatsal Manot
//

import CombineX
import SwiftUIX

public struct RequestButton<R: Request, Label: View>: View {
    public enum ButtonState {
        case inactive
        case active
        case complete(R.Result)
    }
    
    private let request: R
    private let session: AnyRequestSession<R>
    private let completion: (R.Result) -> ()
    private let label: Label
    
    private var canRetry: Bool = true
    
    @State private var didTry: Bool = false
    @State private var state: ButtonState = .inactive
    
    public init(
        request: R,
        session: AnyRequestSession<R>,
        completion: @escaping (R.Result) -> (),
        @ViewBuilder label: () -> Label
    ) {
        self.request = request
        self.session = session
        self.completion = completion
        self.label = label()
    }
    
    @State var cancellable: AnyCancellable?
    
    public var body: some View {
        Button(action: trigger) {
            ZStack {
                label.hidden(cancellable != nil)
                ActivityIndicator().hidden(cancellable == nil)
            }
        }.contextMenu {
            Button("Cancel", action: cancel)
        }
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
            .toFuture()
            .sinkResult(complete)
        
        state = .active
    }
    
    func cancel() {
        cancellable?.cancel()
        cancellable = nil
        
        state = .inactive
    }
    
    func complete(_ result: R.Result) {
        didTry = true
        
        completion(result)
        
        state = .complete(result)
    }
}

extension RequestButton {
    public func canRetry(_ canRetry: Bool) -> Self {
        then({ $0.canRetry = canRetry })
    }
}
