public final class SceneCatalogue {
    public typealias Loader = (String) throws -> String

    private let load: Loader
    private var cache: [String: SceneFile] = [:]
    private var importCache: [String: ImportFile] = [:]

    public init(load: @escaping Loader) {
        self.load = load
    }

    public func sceneFile(at resPath: String) throws -> SceneFile {
        if let hit = cache[resPath] { return hit }
        let text = try load(resPath)
        let parsed = try SceneFile.parse(text)
        cache[resPath] = parsed
        return parsed
    }

    /// Whether `resPath` is a text scene, whose nodes can be read. Any other file a scene
    /// instances is one Godot imports as a scene (a model) or a binary `.scn`.
    public static func isTextScene(_ resPath: String) -> Bool {
        resPath.hasSuffix(".tscn")
    }

    /// The `.import` file beside `resPath`, a file Godot imports.
    public func importFile(for resPath: String) throws -> ImportFile {
        if let hit = importCache[resPath] { return hit }
        let parsed = try ImportFile.parse(try load(resPath + ".import"))
        importCache[resPath] = parsed
        return parsed
    }

    /// Walks inheritance + ext_resource PackedScene refs from `resPath`
    /// and throws `ResolveError.cyclicInheritance` if a cycle is found.
    public func detectCycle(startingFrom resPath: String) throws {
        var stack: [String] = []
        try visit(resPath, stack: &stack)
    }

    private func visit(_ resPath: String, stack: inout [String]) throws {
        if let idx = stack.firstIndex(of: resPath) {
            throw ResolveError.cyclicInheritance(path: Array(stack[idx...]) + [resPath])
        }
        // An imported scene instances nothing a text file names.
        guard SceneCatalogue.isTextScene(resPath) else { return }
        stack.append(resPath)
        let scene = try sceneFile(at: resPath)
        // Follow root-node inheritance (instance= on root).
        if let root = scene.rootNode, let instanceId = root.instance,
           let ext = scene.extResource(id: instanceId) {
            try visit(ext.path, stack: &stack)
        }
        // Follow all ext_resource PackedScene refs so nested scenes also
        // get cycle-checked (resolver stops at the boundary, but cycle
        // detection crosses it).
        for ext in scene.extResources where ext.type == "PackedScene" {
            try visit(ext.path, stack: &stack)
        }
        stack.removeLast()
    }
}
