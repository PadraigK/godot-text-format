/// The animation names a project's files hold: the libraries a scene attaches to its animation
/// mixers, the animations in a library file, and the animations in each SpriteFrames.
public enum AnimationExtractor {
    /// A node that holds animation libraries: an AnimationPlayer, an AnimationTree, or a class that
    /// extends one. It's found by its `libraries` property, so its type in the scene can be any class.
    public struct AnimationMixerInfo: Equatable {
        public let nodeName: String
        public let nodePath: String        // e.g. "." or "Spinner/AnimPlayer"
        public let libraries: [LibraryInfo]
        public init(nodeName: String, nodePath: String, libraries: [LibraryInfo]) {
            self.nodeName = nodeName
            self.nodePath = nodePath
            self.libraries = libraries
        }
    }

    /// One of a mixer's libraries: its name, `""` for the default library, and its animations.
    public struct LibraryInfo: Equatable {
        public let libraryName: String
        public let animations: Animations
        public init(libraryName: String, animations: Animations) {
            self.libraryName = libraryName
            self.animations = animations
        }
    }

    /// Where a library's animations are.
    public enum Animations: Equatable {
        /// A library the scene holds as a sub-resource, with its animation names.
        case names([String])
        /// A library in its own file, by its `res://` path; `animationNames(inLibrary:)` reads a
        /// text one.
        case file(String)
    }

    /// Each node in `scene` that sets `libraries`, with its libraries in the order the file
    /// lists them.
    public static func extract(from scene: SceneFile) -> [AnimationMixerInfo] {
        scene.nodes.compactMap { node in
            let libraries = extractLibraries(from: node, in: scene)
            guard !libraries.isEmpty else { return nil }
            let path: String
            if let parent = node.parentPath {
                path = parent == "." ? node.name : parent + "/" + node.name
            } else {
                path = node.name
            }
            return AnimationMixerInfo(nodeName: node.name, nodePath: path, libraries: libraries)
        }
    }

    /// The animation names of an AnimationLibrary file, in the order it lists them; nil for a file
    /// of another type.
    public static func animationNames(inLibrary file: ResourceFile) -> [String]? {
        guard file.type == "AnimationLibrary" else { return nil }
        return libraryNames(file.resource?.prop("_data"))
    }

    /// The animation names of each SpriteFrames sub-resource in `scene`, one list per resource, in
    /// the order the file has them.
    public static func spriteFrames(in scene: SceneFile) -> [[String]] {
        scene.subResources.filter { $0.type == "SpriteFrames" }.map { spriteFramesNames($0.prop("animations")) }
    }

    /// The animation names of a SpriteFrames file, in its order; nil for a file of another type.
    public static func animationNames(inSpriteFrames file: ResourceFile) -> [String]? {
        guard file.type == "SpriteFrames" else { return nil }
        return spriteFramesNames(file.resource?.prop("animations"))
    }

    private static func extractLibraries(from node: SceneFile.NodeEntry, in scene: SceneFile) -> [LibraryInfo] {
        // Godot 4 writes one `libraries/<name> = …` line per library, `libraries/` for the
        // default one, and still reads the older `libraries = { "": … }` dictionary. Read whichever
        // is present, the dotted form first, since that's what the engine writes.
        var refs: [(libraryName: String, value: Value)] = []
        for (key, value) in node.body where key.hasPrefix("libraries/") {
            refs.append((String(key.dropFirst("libraries/".count)), value))
        }
        if refs.isEmpty, case .dictionary(let pairs) = node.prop("libraries") ?? .null {
            for (key, value) in pairs {
                switch key {
                case .string(let name), .stringName(let name): refs.append((name, value))
                default: continue
                }
            }
        }
        return refs.compactMap { libraryName, value in
            switch value {
            case .subResource(let id):
                guard let library = scene.subResource(id: id), library.type == "AnimationLibrary" else { return nil }
                return LibraryInfo(libraryName: libraryName, animations: .names(libraryNames(library.prop("_data"))))
            case .extResource(let id):
                guard let file = scene.extResource(id: id) else { return nil }
                return LibraryInfo(libraryName: libraryName, animations: .file(file.path))
            default:
                return nil
            }
        }
    }

    /// A library's `_data` keys: StringNames (`&"title"`) as Godot writes them, or plain strings
    /// in older files.
    private static func libraryNames(_ data: Value?) -> [String] {
        guard case .dictionary(let pairs) = data ?? .null else { return [] }
        return pairs.compactMap { key, _ in
            switch key {
            case .stringName(let name), .string(let name): return name
            default: return nil
            }
        }
    }

    /// The `"name"` of each entry in a SpriteFrames' `animations` array.
    private static func spriteFramesNames(_ animations: Value?) -> [String] {
        guard case .array(let entries) = animations ?? .null else { return [] }
        return entries.compactMap { entry in
            guard case .dictionary(let pairs) = entry else { return nil }
            for (key, value) in pairs {
                guard case .string("name") = key else { continue }
                switch value {
                case .stringName(let name), .string(let name): return name
                default: return nil
                }
            }
            return nil
        }
    }
}
