public enum AnimationExtractor {
    public struct AnimationPlayerInfo: Equatable {
        public let nodeName: String
        public let nodePath: String        // e.g. "." or "Spinner/AnimPlayer"
        public let libraries: [LibraryInfo]
        public init(nodeName: String, nodePath: String, libraries: [LibraryInfo]) {
            self.nodeName = nodeName
            self.nodePath = nodePath
            self.libraries = libraries
        }
    }

    public struct LibraryInfo: Equatable {
        public let libraryName: String       // "" for default
        public let animationNames: [String]
        public init(libraryName: String, animationNames: [String]) {
            self.libraryName = libraryName
            self.animationNames = animationNames
        }
    }

    public static func extract(from scene: SceneFile) -> [AnimationPlayerInfo] {
        scene.nodes.compactMap { node in
            guard node.type == "AnimationPlayer" else { return nil }
            let path: String
            if let parent = node.parentPath {
                path = parent == "." ? node.name : parent + "/" + node.name
            } else {
                path = node.name
            }
            let libs = extractLibraries(from: node, in: scene)
            return AnimationPlayerInfo(nodeName: node.name, nodePath: path, libraries: libs)
        }
    }

    private static func extractLibraries(from node: SceneFile.NodeEntry, in scene: SceneFile) -> [LibraryInfo] {
        // Godot serializes AnimationPlayer.libraries one of two ways:
        //
        //   1. Inline dictionary — `libraries = { "": SubResource(...) }`.
        //      Compact; sometimes seen in hand-authored fixtures.
        //   2. Dotted-key per entry — `libraries/ = SubResource(...)` for
        //      the default library, `libraries/<name> = SubResource(...)`
        //      for each named library. This is what Godot 4 actually
        //      writes when you edit + save through the editor.
        //
        // Read whichever form is present; prefer the dotted form when both
        // appear, since that's what the engine round-trips through.
        var libRefs: [(libraryName: String, subId: String)] = []
        for (key, value) in node.body where key.hasPrefix("libraries/") {
            guard case .subResource(let subId) = value else { continue }
            let libName = String(key.dropFirst("libraries/".count))
            libRefs.append((libName, subId))
        }
        if libRefs.isEmpty,
           case .dictionary(let pairs) = node.prop("libraries") ?? .null {
            for (key, ref) in pairs {
                guard case .string(let libName) = key else { continue }
                guard case .subResource(let subId) = ref else { continue }
                libRefs.append((libName, subId))
            }
        }
        return libRefs.compactMap { libName, subId in
            guard let lib = scene.subResource(id: subId),
                  lib.type == "AnimationLibrary" else { return nil }
            guard case .dictionary(let data) = lib.prop("_data") ?? .null else { return nil }
            // `_data` keys are typically StringName literals (`&"title"`),
            // but older files used plain quoted strings — accept both.
            let names: [String] = data.compactMap { k, _ in
                switch k {
                case .stringName(let s), .string(let s): return s
                default: return nil
                }
            }
            return LibraryInfo(libraryName: libName, animationNames: names)
        }
    }
}
