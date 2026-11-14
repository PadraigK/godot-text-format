public struct ParseError: Error, CustomStringConvertible, Equatable {
    public let message: String
    public let location: SourceLocation

    public init(_ message: String, at location: SourceLocation) {
        self.message = message
        self.location = location
    }

    public var description: String {
        "parse error at line \(location.line), column \(location.column): \(message)"
    }
}

public enum ResolveError: Error, Equatable {
    case sceneNotFound(String)
    case cyclicInheritance(path: [String])
    case inheritedResourceMissing(id: String, in: String)
    case notAScene(String)
    /// An inherited or instanced scene that is neither a text scene (`.tscn`) nor a file Godot
    /// imports as one, with its `.import` file beside it: a binary `.scn`, for one.
    case sceneNotReadable(String)
}
