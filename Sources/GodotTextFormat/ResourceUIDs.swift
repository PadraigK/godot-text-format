/// Where a project's `uid://` references point. Godot keeps a resource's uid in its own file, in
/// the header of a scene or resource (`[gd_scene format=3 uid="uid://…"]`), or, for a file that
/// can't hold one (a script, a shader), in a `.uid` file beside it (`player.gd.uid`).
public enum ResourceUIDs {
    /// The number a `uid://` text stands for, as `ResourceUID::text_to_id` reads it: after
    /// `uid://`, each character is a digit in base 34, `a` to `z` from 0 and `0` to `9` from 25,
    /// and the sum is kept to its low 63 bits. So `z` reads as `0` does, and text longer than
    /// Godot writes wraps, as it does in Godot. Nil where Godot gives its invalid id, -1: text
    /// that doesn't start with `uid://`, or holds any other character.
    public static func id(of text: String) -> Int64? {
        guard text.hasPrefix("uid://") else { return nil }
        var id: UInt64 = 0
        for character in text.utf8.dropFirst("uid://".utf8.count) {
            id = id &* 34
            switch character {
            case UInt8(ascii: "a")...UInt8(ascii: "z"):
                id = id &+ UInt64(character - UInt8(ascii: "a"))
            case UInt8(ascii: "0")...UInt8(ascii: "9"):
                id = id &+ UInt64(character - UInt8(ascii: "0")) + 25
            default:
                return nil
            }
        }
        return Int64(id & 0x7FFF_FFFF_FFFF_FFFF)
    }

    /// The `uid://` text Godot writes for a resource's number, as `ResourceUID::id_to_text`
    /// writes it: base 34, `a` to `y` and then `0` to `8`. Nil for a negative number, which
    /// names no resource.
    public static func text(of id: Int64) -> String? {
        guard id >= 0 else { return nil }
        let characters = Array("abcdefghijklmnopqrstuvwxy012345678".utf8)
        var digits: [UInt8] = []
        var rest = id
        repeat {
            digits.append(characters[Int(rest % Int64(characters.count))])
            rest /= Int64(characters.count)
        } while rest != 0
        return "uid://" + String(decoding: digits.reversed(), as: UTF8.self)
    }

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
