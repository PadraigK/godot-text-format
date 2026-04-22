/// An `[ext_resource ...]` section — an external resource reference.
public struct ExtResourceEntry: Equatable {
    public let id: String
    public let type: String
    public let path: String
    public let uid: String?
    public init(id: String, type: String, path: String, uid: String?) {
        self.id = id
        self.type = type
        self.path = path
        self.uid = uid
    }
}

/// A `[sub_resource ...]` section — an embedded resource definition.
public struct SubResourceEntry: Equatable {
    public let id: String
    public let type: String
    public let body: [(String, Value)]
    public init(id: String, type: String, body: [(String, Value)]) {
        self.id = id
        self.type = type
        self.body = body
    }
    public func prop(_ name: String) -> Value? {
        body.first(where: { $0.0 == name })?.1
    }

    public static func == (lhs: SubResourceEntry, rhs: SubResourceEntry) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
            && lhs.body.count == rhs.body.count
            && zip(lhs.body, rhs.body).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
    }
}
