public struct ResourceFile {
    public let format: Int
    public let type: String
    public let uid: String?
    public let extResources: [SceneFile.ExtResourceEntry]
    public let subResources: [SceneFile.SubResourceEntry]
    public let resource: Section?

    public static func parse(_ source: String) throws -> ResourceFile {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = SectionParser(tokens: tokens)
        let sections = try parser.parseDocument()
        return try ResourceFile(sections: sections)
    }

    public init(sections: [Section]) throws {
        var format = 0
        var type = ""
        var uid: String? = nil
        var ext: [SceneFile.ExtResourceEntry] = []
        var sub: [SceneFile.SubResourceEntry] = []
        var resource: Section? = nil

        for section in sections {
            switch section.kind {
            case "gd_resource":
                if case .int(let f) = section.attr("format") ?? .null { format = Int(f) }
                if case .string(let t) = section.attr("type") ?? .null { type = t }
                if case .string(let u) = section.attr("uid") ?? .null { uid = u }
            case "ext_resource":
                guard case .string(let id) = section.attr("id") ?? .null,
                      case .string(let t) = section.attr("type") ?? .null,
                      case .string(let p) = section.attr("path") ?? .null else {
                    throw ParseError("ext_resource missing fields", at: section.headerRange.start)
                }
                var u: String? = nil
                if case .string(let uu) = section.attr("uid") ?? .null { u = uu }
                ext.append(.init(id: id, type: t, path: p, uid: u))
            case "sub_resource":
                guard case .string(let id) = section.attr("id") ?? .null,
                      case .string(let t) = section.attr("type") ?? .null else {
                    throw ParseError("sub_resource missing fields", at: section.headerRange.start)
                }
                sub.append(.init(id: id, type: t, body: section.body))
            case "resource":
                resource = section
            default:
                break
            }
        }

        self.format = format
        self.type = type
        self.uid = uid
        self.extResources = ext
        self.subResources = sub
        self.resource = resource
    }
}
