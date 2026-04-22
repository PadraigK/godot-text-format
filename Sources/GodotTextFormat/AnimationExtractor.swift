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
        guard case .dictionary(let pairs) = node.prop("libraries") ?? .null else { return [] }
        return pairs.compactMap { key, ref in
            guard case .string(let libName) = key else { return nil }
            guard case .subResource(let subId) = ref else { return nil }
            guard let lib = scene.subResource(id: subId), lib.type == "AnimationLibrary" else { return nil }
            guard case .dictionary(let data) = lib.prop("_data") ?? .null else { return nil }
            let names: [String] = data.compactMap { k, _ in
                if case .string(let s) = k { return s }
                return nil
            }
            return LibraryInfo(libraryName: libName, animationNames: names)
        }
    }
}
