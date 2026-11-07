/// An entry of `project.godot`'s `[autoload]` or `[autoload_prepend]`: a node Godot makes from a
/// scene or script and adds under the scene tree's root, by `name`, when the game starts.
public struct Autoload: Equatable {
    public let name: String
    /// The scene or script as the entry gives it, a `res://` path or a `uid://`, without the `*`.
    public let path: String
    /// The entry starts with `*`, so scripts also reach the node by `name` as a global. Godot adds
    /// the node either way.
    public let isGlobal: Bool

    public init(name: String, path: String, isGlobal: Bool) {
        self.name = name
        self.path = path
        self.isGlobal = isGlobal
    }
}

extension ProjectFile {
    /// The project's autoloads in the order Godot adds them, as `ProjectSettings` builds its list
    /// from the file's lines: an `[autoload]` entry goes last, or keeps its place when the name is
    /// already listed, and an `[autoload_prepend]` entry goes first, replacing one of the same name.
    public var autoloads: [Autoload] {
        var list: [Autoload] = []
        for section in sections where section.kind == "autoload" || section.kind == "autoload_prepend" {
            for (name, value) in section.body {
                guard case .string(let text) = value else { continue }
                let isGlobal = text.hasPrefix("*")
                let entry = Autoload(name: name, path: isGlobal ? String(text.dropFirst()) : text, isGlobal: isGlobal)
                let existing = list.firstIndex(where: { $0.name == name })
                if section.kind == "autoload_prepend" {
                    if let existing { list.remove(at: existing) }
                    list.insert(entry, at: 0)
                } else if let existing {
                    list[existing] = entry
                } else {
                    list.append(entry)
                }
            }
        }
        return list
    }
}
