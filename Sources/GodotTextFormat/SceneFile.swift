public struct SceneFile {
    public let format: Int
    public let uid: String?
    public let extResources: [ExtResourceEntry]
    public let subResources: [SubResourceEntry]
    public let nodes: [NodeEntry]
    public let connections: [ConnectionEntry]
    public let editableInstances: [String]

    public struct NodeEntry {
        public let name: String
        public let type: String?            // absent for inherited/instanced
        public let parentPath: String?      // nil for root
        public let index: Int?
        public let owner: String?
        public let instance: String?        // ExtResource id
        public let instancePlaceholder: String?
        public let groups: [String]
        public let body: [(String, Value)]
        public func prop(_ name: String) -> Value? {
            body.first(where: { $0.0 == name })?.1
        }
    }

    public struct ConnectionEntry {
        public let signal: String
        public let from: String
        public let to: String
        public let method: String
        public let body: [(String, Value)]
    }

    public static func parse(_ source: String) throws -> SceneFile {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = SectionParser(tokens: tokens)
        let sections = try parser.parseDocument()
        return try SceneFile(sections: sections)
    }

    public init(sections: [Section]) throws {
        var format = 0
        var uid: String? = nil
        var ext: [ExtResourceEntry] = []
        var sub: [SubResourceEntry] = []
        var nodes: [NodeEntry] = []
        var connections: [ConnectionEntry] = []
        var editables: [String] = []

        for section in sections {
            switch section.kind {
            case "gd_scene":
                if case .int(let f) = section.attr("format") ?? .null { format = Int(f) }
                if case .string(let s) = section.attr("uid") ?? .null { uid = s }
            case "ext_resource":
                ext.append(try Self.extResource(from: section))
            case "sub_resource":
                sub.append(try Self.subResource(from: section))
            case "node":
                nodes.append(try Self.nodeEntry(from: section))
            case "connection":
                connections.append(try Self.connection(from: section))
            case "editable":
                if case .nodePath(let p) = section.attr("path") ?? .null {
                    editables.append(p)
                } else if case .string(let p) = section.attr("path") ?? .null {
                    editables.append(p)
                }
            default:
                break
            }
        }

        self.format = format
        self.uid = uid
        self.extResources = ext
        self.subResources = sub
        self.nodes = nodes
        self.connections = connections
        self.editableInstances = editables
    }

    private static func extResource(from s: Section) throws -> ExtResourceEntry {
        guard case .string(let id) = s.attr("id") ?? .null else {
            throw ParseError("ext_resource missing id", at: s.headerRange.start)
        }
        guard case .string(let type) = s.attr("type") ?? .null else {
            throw ParseError("ext_resource missing type", at: s.headerRange.start)
        }
        guard case .string(let path) = s.attr("path") ?? .null else {
            throw ParseError("ext_resource missing path", at: s.headerRange.start)
        }
        var uid: String? = nil
        if case .string(let u) = s.attr("uid") ?? .null { uid = u }
        return .init(id: id, type: type, path: path, uid: uid)
    }

    private static func subResource(from s: Section) throws -> SubResourceEntry {
        guard case .string(let id) = s.attr("id") ?? .null else {
            throw ParseError("sub_resource missing id", at: s.headerRange.start)
        }
        guard case .string(let type) = s.attr("type") ?? .null else {
            throw ParseError("sub_resource missing type", at: s.headerRange.start)
        }
        return .init(id: id, type: type, body: s.body)
    }

    private static func nodeEntry(from s: Section) throws -> NodeEntry {
        guard case .string(let name) = s.attr("name") ?? .null else {
            throw ParseError("node missing name", at: s.headerRange.start)
        }
        var type: String? = nil
        if case .string(let t) = s.attr("type") ?? .null { type = t }

        var parent: String? = nil
        switch s.attr("parent") {
        case .some(.string(let p)): parent = p
        case .some(.nodePath(let p)): parent = p
        default: break
        }

        var index: Int? = nil
        if case .int(let i) = s.attr("index") ?? .null { index = Int(i) }

        var owner: String? = nil
        if case .nodePath(let p) = s.attr("owner") ?? .null { owner = p }

        var instance: String? = nil
        if case .extResource(let id) = s.attr("instance") ?? .null { instance = id }

        var placeholder: String? = nil
        if case .string(let p) = s.attr("instance_placeholder") ?? .null { placeholder = p }

        var groups: [String] = []
        if case .array(let arr) = s.attr("groups") ?? .null {
            for v in arr {
                if case .stringName(let g) = v { groups.append(g) }
                else if case .string(let g) = v { groups.append(g) }
            }
        }

        return .init(
            name: name, type: type, parentPath: parent, index: index, owner: owner,
            instance: instance, instancePlaceholder: placeholder, groups: groups,
            body: s.body
        )
    }

    private static func connection(from s: Section) throws -> ConnectionEntry {
        func stringOrPath(_ v: Value?) -> String? {
            switch v {
            case .some(.string(let s)): return s
            case .some(.nodePath(let s)): return s
            case .some(.stringName(let s)): return s
            default: return nil
            }
        }
        guard let signal = stringOrPath(s.attr("signal")) else {
            throw ParseError("connection missing signal", at: s.headerRange.start)
        }
        guard let from = stringOrPath(s.attr("from")) else {
            throw ParseError("connection missing from", at: s.headerRange.start)
        }
        guard let to = stringOrPath(s.attr("to")) else {
            throw ParseError("connection missing to", at: s.headerRange.start)
        }
        guard let method = stringOrPath(s.attr("method")) else {
            throw ParseError("connection missing method", at: s.headerRange.start)
        }
        return .init(signal: signal, from: from, to: to, method: method, body: s.body)
    }

    public var rootNode: NodeEntry? { nodes.first }
    public func extResource(id: String) -> ExtResourceEntry? {
        extResources.first(where: { $0.id == id })
    }
    public func subResource(id: String) -> SubResourceEntry? {
        subResources.first(where: { $0.id == id })
    }
}
