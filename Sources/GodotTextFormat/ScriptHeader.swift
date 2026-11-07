/// What a GDScript file says it is, from the lines at its top: its `class_name` and what it
/// `extends`. GDScript allows only annotations (`@tool`, `@icon("…")`), comments and these two
/// before anything else, in either order and on one line or two, so reading stops at the first
/// other statement.
public struct ScriptHeader: Equatable {
    /// What a script extends.
    public enum Base: Equatable {
        /// A class by name as written: an engine class, a global class, or an inner class of one
        /// (`Node2D`, `Player`, `Player.Hitbox`).
        case named(String)
        /// A script by path, or an inner class of it: `extends "res://player.gd"`, or
        /// `extends "res://player.gd".Hitbox` with `inner` `"Hitbox"`.
        case script(path: String, inner: String?)
    }

    public let className: String?
    /// Nil when the script has no `extends`, which makes it a `RefCounted`.
    public let base: Base?

    public init(className: String?, base: Base?) {
        self.className = className
        self.base = base
    }

    public static func parse(_ source: String) -> ScriptHeader {
        var className: String?
        var base: Base?
        lines: for line in source.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            var tokens = HeaderToken.tokens(in: line)[...]
            while let token = tokens.first {
                switch token {
                case .annotation:
                    tokens = tokens.dropFirst()
                case .word("class_name"):
                    guard case .word(let name)? = tokens.dropFirst().first else { break lines }
                    className = name
                    tokens = tokens.dropFirst(2)
                case .word("extends"):
                    switch tokens.dropFirst().first {
                    case .word(let name)?:
                        base = .named(name)
                        tokens = tokens.dropFirst(2)
                    case .string(let path)?:
                        if case .word(let inner)? = tokens.dropFirst(2).first, inner.hasPrefix(".") {
                            base = .script(path: path, inner: String(inner.dropFirst()))
                            tokens = tokens.dropFirst(3)
                        } else {
                            base = .script(path: path, inner: nil)
                            tokens = tokens.dropFirst(2)
                        }
                    default:
                        break lines
                    }
                default:
                    break lines
                }
            }
        }
        return ScriptHeader(className: className, base: base)
    }
}

/// A piece of a line at a script's top: an annotation with any arguments, a word (a keyword or a
/// name, dots included), a string, or anything else. A comment ends the line.
private enum HeaderToken: Equatable {
    case annotation
    case word(String)
    case string(String)
    case other

    static func tokens(in line: Substring) -> [HeaderToken] {
        var tokens: [HeaderToken] = []
        var rest = line[...]
        func isWordCharacter(_ c: Character) -> Bool { c == "_" || c == "." || c.isLetter || c.isNumber }
        while let c = rest.first {
            if c == " " || c == "\t" || c == ";" {
                rest = rest.dropFirst()
            } else if c == "#" {
                break
            } else if c == "@" {
                rest = rest.dropFirst().drop(while: isWordCharacter)
                if rest.first == "(" {
                    rest = skipParentheses(rest)
                }
                tokens.append(.annotation)
            } else if c == "\"" || c == "'" {
                let (text, after) = quoted(rest)
                tokens.append(.string(text))
                rest = after
            } else if isWordCharacter(c) {
                let word = rest.prefix(while: isWordCharacter)
                tokens.append(.word(String(word)))
                rest = rest.dropFirst(word.count)
            } else {
                tokens.append(.other)
                rest = rest.dropFirst()
            }
        }
        return tokens
    }

    /// `text` past its parenthesised arguments, strings in them included.
    private static func skipParentheses(_ text: Substring) -> Substring {
        var depth = 0
        var rest = text
        while let c = rest.first {
            if c == "\"" || c == "'" {
                rest = quoted(rest).after
                continue
            }
            rest = rest.dropFirst()
            if c == "(" { depth += 1 }
            if c == ")" { depth -= 1; if depth == 0 { break } }
        }
        return rest
    }

    /// The string `text` starts with, unescaped, and what follows it.
    private static func quoted(_ text: Substring) -> (text: String, after: Substring) {
        let quote = text.first!
        var value = ""
        var rest = text.dropFirst()
        while let c = rest.first {
            rest = rest.dropFirst()
            if c == quote { return (value, rest) }
            if c == "\\", let next = rest.first {
                value.append(next)
                rest = rest.dropFirst()
            } else {
                value.append(c)
            }
        }
        return (value, rest)
    }
}
