//
// Copyright (c) Vatsal Manot
//

import Foundation
import Merge
import Swallow

final class _ClientEndpointTask<Client: SwiftAPI.Client, Endpoint: SwiftAPI.Endpoint>: ObservableTask where Endpoint.Root == Client.API {
    typealias Success = Endpoint.Output
    typealias Error = Client.API.Error
    
    let client: Client
    let endpoint: Endpoint
    let input: Endpoint.Input
    let options: Endpoint.Options
    
    private let base: AnyTask<Endpoint.Output, Client.API.Error>
    
    var status: TaskStatus<Endpoint.Output, Client.API.Error> {
        base.status
    }
    
    var objectWillChange: AnyTask<Endpoint.Output, Client.API.Error>.ObjectWillChangePublisher {
        base.objectWillChange
    }
    
    var objectDidChange: AnyTask<Endpoint.Output, Client.API.Error>.ObjectDidChangePublisher {
        base.objectDidChange
    }

    init(
        client: Client,
        endpoint: Endpoint,
        input: Endpoint.Input,
        options: Endpoint.Options,
        cache: AnyKeyedCache<Endpoint.Request, Endpoint.Request.Response>
    ) {
        self.client = client
        self.endpoint = endpoint
        self.input = input
        self.options = options
        
        self.base = PassthroughTask(body: { task in
            do {
                let request = try endpoint.buildRequest(
                    from: input,
                    context: .init(root: client.interface, options: options)
                )
                
                if let response = try? cache.retrieveInMemoryValue(forKey: request), let output = try? endpoint.decodeOutput(from: response, context: .init(root: client.interface, input: input, options: options, request: request)) {
                    task.send(status: .success(output))
                    
                    return .empty()
                }
                
                return client
                    .session
                    .task(with: request)
                    .successPublisher
                    .mapError {
                        switch $0 {
                            case .canceled:
                                return try! Client.API.Request.Error(_catchAll: CancellationError())!
                            case .error(let error):
                                return error
                        }
                    }
                    .sinkResult({ [weak task] (result: Result<Endpoint.Root.Request.Response, Endpoint.Root.Request.Error>) in
                        guard let task = `task` else {
                            assertionFailure()
                            
                            return
                        }
                        
                        switch result {
                            case .success(let value): do {
                                do {
                                    let output = try endpoint.decodeOutput(
                                        from: value,
                                        context: .init(
                                            root: client.interface,
                                            input: input,
                                            options: options,
                                            request: request
                                        )
                                    )
                                    
                                    task.send(status: .success(output))
                                } catch {
                                    if let error = error as? Client.API.Error {
                                        task.send(status: .error(error))
                                    } else {
                                        task.send(status: .error(.runtime(error)))
                                    }
                                    
                                    client.logger.error(
                                        error,
                                        metadata: ["request": request]
                                    )
                                }
                            }
                            case .failure(let error): do {
                                task.send(status: .error(.runtime(error)))
                                
                                client.logger.error(error, metadata: ["request": request])
                            }
                        }
                    })
            } catch {
                task.send(status: .error(.runtime(error)))
                
                client.logger.debug("Failed to construct an API request.")
                client.logger.error(error)
                
                return AnyCancellable.empty()
            }
        })
        .eraseToAnyTask()
    }
    
    func start() {
        base.start()
    }
    
    func cancel() {
        base.cancel()
    }
}
