//
// Copyright (c) Vatsal Manot
//

import Merge
import Swallow

final class RESTfulResourceEndpointCoordinator<
    Repository: API.Repository,
    Endpoint: API.Endpoint,
    Value
>: Cancellable, Resettable where Repository.Interface == Endpoint.Root {
    @usableFromInline
    class EndpointDependency {
        func isAvailable(in repository: Repository) -> Bool {
            fatalError()
        }
    }
    
    private let cancellables = Cancellables()
    
    weak var parent: Repository?
    
    let dependencyGraph: (Repository) throws -> [EndpointDependency]
    let endpoint: (Repository) throws -> Endpoint
    let input: (Repository) throws -> Endpoint.Input
    let output: (Endpoint.Output) throws -> Value
    
    @Published var endpointTask: AnyTask<Endpoint.Output, Endpoint.Root.Error>?
    @Published var lastResult: TaskResult<Value, Swift.Error>?
    
    init(
        dependencyGraph: @escaping (Repository) throws -> [EndpointDependency],
        endpoint: @escaping (Repository) throws -> Endpoint,
        input: @escaping (Repository) throws -> Endpoint.Input,
        output: @escaping (Endpoint.Output) throws -> Value
    ) {
        self.dependencyGraph = dependencyGraph
        self.endpoint = endpoint
        self.input = input
        self.output = output
    }
    
    func cancel() {
        endpointTask?.cancel()
    }
    
    func reset() {
        endpointTask?.cancel()
        endpointTask = nil
        lastResult = nil
    }
    
    func run() -> AnyTask<Value, Swift.Error> {
        do {
            endpointTask?.cancel()
            
            let repository = try parent.unwrap()
            
            let endpoint = try self.endpoint(repository)
            var endpointOptions = try endpoint.makeDefaultOptions()
            
            /// Handle paginating endpoints that support automatic pagination.
            if let latestValue = self.lastResult?.value as? _opaque_PaginatedListType {
                if var _options = endpointOptions as? CursorPaginated {
                    _options.paginationCursor = latestValue.nextCursor
                    
                    endpointOptions = try cast(endpointOptions)
                }
            }
            
            let endpointTask = repository.run(
                endpoint,
                with: try input(repository),
                options: endpointOptions
            )
            
            defer {
                self.endpointTask = endpointTask
            }
            
            let resultTask = PassthroughTask<Value, Error>()
            
            endpointTask
                .resultPublisher
                .sink(in: cancellables) { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    
                    resultTask.send(status: .init(self.handleEndpointOutput(result)))
                }
            
            return resultTask.eraseToAnyTask()
        } catch {
            lastResult = .error(error)
            
            return .failure(error)
        }
    }
    
    private func handleEndpointOutput(
        _ output: TaskResult<Endpoint.Output, Repository.Interface.Error>
    ) -> TaskResult<Value, Error> {
        var result: TaskResult<Value, Error>
        
        endpointTask = nil
        
        do {
            result = try output
                .map(self.output)
                .mapError({ $0 as Swift.Error })
            
            if var _result = try lastResult?.get() as? _opaque_PaginatedListType, let newResult = try result.get() as? _opaque_PaginatedListType {
                try _result._opaque_concatenateInPlace(with: newResult)
                
                result = .success(try cast(_result, to: Value.self))
            }
        } catch {
            result = .error(error)
        }
        
        lastResult = result
        
        return result
    }
    
    // MARK: - Initializers
    
    init(
        dependencyGraph: @escaping (Repository) throws -> [EndpointDependency],
        endpoint: KeyPath<Endpoint.Root, Endpoint>,
        input: @escaping (Repository) throws -> Endpoint.Input = { _ in throw Never.Reason.unimplemented },
        output: @escaping (Endpoint.Output) throws -> Value = { _ in throw Never.Reason.unimplemented }
    ) {
        self.dependencyGraph = dependencyGraph
        self.endpoint = { $0.interface[keyPath: endpoint] }
        self.input = input
        self.output = output
    }
    
    convenience init() where Endpoint == NeverEndpoint<Repository.Interface> {
        self.init(
            dependencyGraph: { _ in throw Never.Reason.irrational },
            endpoint: { _ in throw Never.Reason.irrational },
            input: { _ in throw Never.Reason.irrational },
            output: Never.materialize
        )
    }
}
