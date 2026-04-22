public struct Section: Equatable {
    public let kind: String
    public let attrs: [(String, Value)]
    public let body: [(String, Value)]
    public let headerRange: SourceRange

    public init(
        kind: String,
        attrs: [(String, Value)],
        body: [(String, Value)],
        headerRange: SourceRange
    ) {
        self.kind = kind
        self.attrs = attrs
        self.body = body
        self.headerRange = headerRange
    }

    public static func == (lhs: Section, rhs: Section) -> Bool {
        lhs.kind == rhs.kind
            && lhs.attrs.count == rhs.attrs.count
            && zip(lhs.attrs, rhs.attrs).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
            && lhs.body.count == rhs.body.count
            && zip(lhs.body, rhs.body).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    }

    public func attr(_ name: String) -> Value? {
        attrs.first(where: { $0.0 == name })?.1
    }

    public func prop(_ name: String) -> Value? {
        body.first(where: { $0.0 == name })?.1
    }
}
