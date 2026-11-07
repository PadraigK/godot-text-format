/// Where a project's `uid://` references point. Godot keeps a resource's uid in its own file, in
/// the header of a scene or resource (`[gd_scene format=3 uid="uid://…"]`), or, for a file that
/// can't hold one (a script, a shader), in a `.uid` file beside it (`player.gd.uid`).
public enum ResourceUIDs {
    /// Whether the file at `path` can declare a uid, so a caller reads only those.
    public static func mayDeclare(_ path: String) -> Bool {
        path.hasSuffix(".uid") || path.hasSuffix(".tscn") || path.hasSuffix(".tres")
    }

    /// The uid the file at `path` declares, with the `res://` path of the resource it belongs to:
    /// for a `.uid` file the file beside it (`res://player.gd.uid` gives `res://player.gd`), for a
    /// scene or resource the file itself. `text` is the file's text; only a scene's or resource's
    /// first line, its header, is read. Nil for a file that declares none.
    public static func declared(at path: String, text: String) -> (uid: String, resourcePath: String)? {
        if path.hasSuffix(".uid") {
            let words = text.split(whereSeparator: \.isWhitespace)
            guard words.count == 1, words[0].hasPrefix("uid://") else { return nil }
            return (String(words[0]), String(path.dropLast(".uid".count)))
        }
        guard path.hasSuffix(".tscn") || path.hasSuffix(".tres") else { return nil }
        let header = text.prefix(while: { $0 != "\n" && $0 != "\r" })
        var lexer = Lexer(source: String(header))
        guard let tokens = try? lexer.tokenize() else { return nil }
        var parser = SectionParser(tokens: tokens)
        guard let section = (try? parser.parseDocument())?.first(where: { $0.kind == "gd_scene" || $0.kind == "gd_resource" }),
              case .string(let uid) = section.attr("uid") ?? .null else { return nil }
        return (uid, path)
    }
}
