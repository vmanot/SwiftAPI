//
// Copyright (c) Vatsal Manot
//

import CombineX
import SwiftUIX

public enum RequestButtonState {
    case inactive
    case active
    case disabled
    case failed(Error)
}

public struct RequestButton<R: Request, Label: View>: View {
    private let request: R
    private let session: AnyRequestSession<R>
    private let completion: (R.Result) -> ()
    private let label: Label
    
    private var canRetry: Bool = true
    
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
            Button("Delete", action: cancel)
        }
    }
    
    func trigger() {
        cancel()
        run()
    }
    
    func run() {
        cancellable = session
            .task(with: request)
            .receiveOnMain()
            .toFuture()
            .sinkResult(complete)
    }
    
    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
    
    func complete(_ result: R.Result) {
        completion(result)
    }
}

extension RequestButton {
    public func canRetry(_ canRetry: Bool) -> Self {
        then({ $0.canRetry = canRetry })
    }
}
