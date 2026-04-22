public struct ProjectFile {
    public let configVersion: Int
    public let preamble: [(String, Value)]   // property lines before any [section]
    public let sections: [Section]           // named sections in order (includes platform variants like [input.macos])

    public static func parse(_ source: String) throws -> ProjectFile {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = SectionParser(tokens: tokens)
        let parsed = try parser.parseDocument()

        var configVersion = 0
        var preamble: [(String, Value)] = []
        var rest: [Section] = []

        for s in parsed {
            if s.kind.isEmpty {
                preamble = s.body
                for (k, v) in preamble where k == "config_version" {
                    if case .int(let i) = v { configVersion = Int(i) }
                }
            } else {
                rest.append(s)
            }
        }

        return ProjectFile(configVersion: configVersion, preamble: preamble, sections: rest)
    }

    public func section(_ name: String) -> Section? {
        sections.first(where: { $0.kind == name })
    }

    public func sections(named name: String) -> [Section] {
        // Returns the base section and any platform variants ([name.macos], etc.)
        sections.filter { $0.kind == name || $0.kind.hasPrefix(name + ".") }
    }
}
