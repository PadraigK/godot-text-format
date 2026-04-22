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
