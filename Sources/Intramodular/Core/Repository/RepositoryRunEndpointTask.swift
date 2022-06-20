//
// Copyright (c) Vatsal Manot
//

import Foundation
import Merge
import Swallow

final class RepositoryRunEndpointTask<Repository: API.Repository, Endpoint: API.Endpoint>: ObservableTask where Endpoint.Root == Repository.Interface {
    typealias Success = Endpoint.Output
    typealias Error = Repository.Interface.Error
    
    let repository: Repository
    let endpoint: Endpoint
    let input: Endpoint.Input
    let options: Endpoint.Options
    
    private let base: AnyTask<Endpoint.Output, Repository.Interface.Error>
    
    var objectWillChange: AnyTask<Endpoint.Output, Repository.Interface.Error>.ObjectWillChangePublisher {
        base.objectWillChange
    }
    
    var status: TaskStatus<Endpoint.Output, Repository.Interface.Error> {
        base.status
    }
    
    var progress: Progress {
        base.progress
    }
        
    init(
        repository: Repository,
        endpoint: Endpoint,
        input: Endpoint.Input,
        options: Endpoint.Options,
        cache: AnyKeyedCache<Endpoint.Request, Endpoint.Request.Response>
    ) {
        self.repository = repository
        self.endpoint = endpoint
        self.input = input
        self.options = options
        
        self.base = PassthroughTask(body: { task in
            do {
                let request = try endpoint.buildRequest(
                    from: input,
                    context: .init(root: repository.interface, options: options)
                )
                
                if let response = try? cache.retrieveInMemoryValue(forKey: request), let output = try? endpoint.decodeOutput(from: response, context: .init(root: repository.interface, input: input, options: options, request: request)) {
                    task.send(status: .success(output))
                    
                    return .empty()
                }
                
                return repository
                    .session
                    .task(with: request)
                    .successPublisher
                    .sinkResult({ [weak task] (result: Result<Endpoint.Root.Request.Response, Endpoint.Root.Request.Error>) in
                        switch result {
                            case .success(let value): do {
                                do {
                                    repository.logger?.debug(
                                        "Received a request response",
                                        metadata: ["response": value]
                                    )
                                    
                                    let output = try endpoint.decodeOutput(
                                        from: value,
                                        context: .init(
                                            root: repository.interface,
                                            input: input,
                                            options: options,
                                            request: request
                                        )
                                    )
                                    
                                    task?.send(status: .success(output))
                                } catch {
                                    task?.send(status: .error(.runtime(error)))
                                    
                                    repository.logger?.error(
                                        error,
                                        metadata: ["request": request]
                                    )
                                }
                            }
                            case .failure(let error): do {
                                task?.send(status: .error(.runtime(error)))
                                
                                repository.logger?.error(error, metadata: ["request": request])
                            }
                        }
                    })
            } catch {
                task.send(status: .error(.runtime(error)))
                
                repository.logger?.debug("Failed to construct an API request.")
                repository.logger?.error(error)
                
                return AnyCancellable.empty()
            }
        })
        .eraseToAnyTask()
    }
    
    func start() {
        base.start()
    }
    
    func pause() throws {
        try base.pause()
    }
    
    func resume() throws {
        try base.resume()
    }
    
    func cancel() {
        base.cancel()
    }
}
