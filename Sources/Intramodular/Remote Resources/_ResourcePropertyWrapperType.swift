//
// Copyright (c) Vatsal Manot
//

import Combine
import Merge
import Swallow

public protocol _ResourcePropertyWrapperType: ObservableObject {
    associatedtype Value
    associatedtype ValueStreamPublisher: Publisher where ValueStreamPublisher.Output == Result<Value, Error>, ValueStreamPublisher.Failure == Never
    
    var configuration: _ResourceConfiguration<Value> { get set }
    var publisher: ValueStreamPublisher { get }
    var latestValue: Value? { get }
    
    func unwrap() throws -> Value?
    
    @discardableResult
    func fetch() -> AnyTask<Value, Error>
}
