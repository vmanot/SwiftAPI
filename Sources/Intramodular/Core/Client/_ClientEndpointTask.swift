//
// Copyright (c) Vatsal Manot
//

import Foundation
import Merge
import Swallow

/// An observable task used by a `Client` to run an endpoint.
///
/// This is an internal type.
final class _ClientEndpointTask<Client: SwiftAPI.Client, Endpoint: SwiftAPI.Endpoint> where Endpoint.Root == Client.API {
    private let client: Client
    private let endpoint: Endpoint
    private let input: Endpoint.Input
    private let options: Endpoint.Options
    private let cache: AnyKeyedCache<Endpoint.Request, Endpoint.Request.Response>
    
    private var base: AnyTask<Endpoint.Output, Client.API.Error>!
        
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
        self.cache = cache
        
        self.base = PassthroughTask(body: { task -> AnyCancellable in
            do {
                return try self._buildTask(for: task)
            } catch {
                task.send(status: .error(.runtime(error)))
                
                self.client.logger.debug("Failed to construct an API request.")
                self.client.logger.error(error)
                
                return AnyCancellable.empty()
            }
        })
        .eraseToAnyTask()
    }
        
    private func _buildRequest() throws -> Endpoint.Request {
        var result = try endpoint.buildRequest(
            from: input,
            context: EndpointBuildRequestContext(
                root: client.interface,
                options: options
            )
        )
        
        client.interface.update(&result)
        
        return result
    }
    
    private func _buildTask(
        for task: PassthroughTask<Endpoint.Output, Client.API.Error>
    ) throws -> AnyCancellable {
        let request = try _buildRequest()
        
        if let response = try? cache.retrieveInMemoryValue(forKey: request), let output = try? endpoint.decodeOutput(from: response, context: .init(root: client.interface, input: input, options: options, request: request)) {
            task.send(status: .success(output))
            
            return AnyCancellable.empty()
        }
        
        let result = client
            .session
            .task(with: request)
            .successPublisher
            .mapError { (error: TaskFailure) in
                switch error {
                    case .canceled:
                        return try! Client.API.Request.Error(_catchAll: CancellationError())!
                    case .error(let error):
                        return error
                }
            }
            .sinkResult { [weak self, weak task] (result: Result<Endpoint.Root.Request.Response, Endpoint.Root.Request.Error>) in
                guard let `self` = self, let task = `task` else {
                    assertionFailure()
                    
                    return
                }
                
                self._forwardResult(
                    result,
                    to: task,
                    fulfilling: request
                )
            }
        
        return result
    }
    
    private func _forwardResult(
        _ result: Result<Endpoint.Root.Request.Response, Endpoint.Root.Request.Error>,
        to task: PassthroughTask<Endpoint.Output, Client.API.Error>,
        fulfilling request: Endpoint.Root.Request
    ) {
        switch result {
            case .success(let value): do {
                do {
                    let output = try self.endpoint.decodeOutput(
                        from: value,
                        context: .init(
                            root: self.client.interface,
                            input: self.input,
                            options: self.options,
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
                    
                    self.client.logger.error(
                        error,
                        metadata: ["request": request]
                    )
                }
            }
            case .failure(let error): do {
                task.send(status: .error(.runtime(error)))
                
                self.client.logger.error(error, metadata: ["request": request])
            }
        }
    }
}

extension _ClientEndpointTask: ObservableTask {
    typealias Success = Endpoint.Output
    typealias Error = Client.API.Error

    var status: TaskStatus<Success, Error> {
        base.status
    }
    
    var objectWillChange: AnyTask<Success, Error>.ObjectWillChangePublisher {
        base.objectWillChange
    }
    
    var objectDidChange: AnyTask<Success, Error>.ObjectDidChangePublisher {
        base.objectDidChange
    }
    
    func start() {
        base.start()
    }
    
    func cancel() {
        base.cancel()
    }
}
