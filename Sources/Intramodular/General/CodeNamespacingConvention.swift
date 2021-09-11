//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

public enum CodeNamespacingConvention: String, Codable {
    case camelCase // fooBar
    case snakeCase // foo_bar
    case kebabCase // foo-bar
}
