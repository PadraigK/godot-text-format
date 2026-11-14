public struct SceneResolver {
    public let catalogue: SceneCatalogue

    public init(catalogue: SceneCatalogue) {
        self.catalogue = catalogue
    }

    public func flatten(resourcePath: String) throws -> FlatScene {
        var visiting: [String] = []
        return try flattenImpl(resourcePath: resourcePath, visiting: &visiting)
    }

    private func flattenImpl(resourcePath: String, visiting: inout [String]) throws -> FlatScene {
        if let idx = visiting.firstIndex(of: resourcePath) {
            throw ResolveError.cyclicInheritance(path: Array(visiting[idx...]) + [resourcePath])
        }
        visiting.append(resourcePath)
        defer { visiting.removeLast() }

        guard SceneCatalogue.isTextScene(resourcePath) else {
            return try importedScene(resourcePath: resourcePath)
        }
        let scene = try catalogue.sceneFile(at: resourcePath)
        guard let rootEntry = scene.rootNode else {
            throw ResolveError.notAScene(resourcePath)
        }

        // Inherited scene: root has `instance=` pointing at another scene.
        if let instanceId = rootEntry.instance, let ext = scene.extResource(id: instanceId) {
            let parent = try flattenImpl(resourcePath: ext.path, visiting: &visiting)
            return try merge(
                parent: parent,
                child: scene,
                childResourcePath: resourcePath,
                childRoot: rootEntry,
                visiting: &visiting
            )
        }

        guard let rootType = rootEntry.type else {
            throw ResolveError.notAScene(resourcePath)
        }

        var nodes: [FlatNode] = []
        var pathIndex: [String: Int] = [:]
        for node in scene.nodes.dropFirst() {
            guard let parentPath = node.parentPath else { continue }
            let path = parentPathComponents(parentPath) + [node.name]
            if overridesImportedNode(node, at: path, rootImported: false, nodes: nodes, index: pathIndex) { continue }
            let (flat, innerNodes) = try makeFlatNode(node: node, path: path, scene: scene, visiting: &visiting)
            appendOrMerge(flat, explicitType: node.type, into: &nodes, index: &pathIndex)
            for inner in innerNodes {
                appendOrMerge(inner, explicitType: inner.type, into: &nodes, index: &pathIndex)
            }
        }

        return FlatScene(
            resourcePath: resourcePath,
            root: FlatNode(
                path: [],
                name: rootEntry.name,
                type: rootType,
                scriptPath: try resolveScriptPath(of: rootEntry, in: scene),
                uniqueInOwner: false,
                groups: rootEntry.groups,
                instanceScenePath: nil
            ),
            nodes: nodes
        )
    }

    private func merge(
        parent: FlatScene,
        child: SceneFile,
        childResourcePath: String,
        childRoot: SceneFile.NodeEntry,
        visiting: inout [String]
    ) throws -> FlatScene {
        var nodes = parent.nodes
        var pathIndex: [String: Int] = [:]
        for (i, n) in nodes.enumerated() {
            pathIndex[n.path.joined(separator: "/")] = i
        }

        for node in child.nodes.dropFirst() {
            guard let parentPath = node.parentPath else { continue }
            let pathComponents = parentPathComponents(parentPath) + [node.name]
            if overridesImportedNode(node, at: pathComponents, rootImported: parent.root.importedScene, nodes: nodes, index: pathIndex) { continue }
            let (flat, innerNodes) = try makeFlatNode(node: node, path: pathComponents, scene: child, visiting: &visiting)
            appendOrMerge(flat, explicitType: node.type, into: &nodes, index: &pathIndex)
            for inner in innerNodes {
                appendOrMerge(inner, explicitType: inner.type, into: &nodes, index: &pathIndex)
            }
        }

        let childRootFlat = FlatNode(
            path: [],
            name: childRoot.name,
            type: childRoot.type ?? parent.root.type,
            scriptPath: try resolveScriptPath(of: childRoot, in: child),
            uniqueInOwner: false,
            groups: childRoot.groups,
            instanceScenePath: nil
        )
        return FlatScene(
            resourcePath: childResourcePath,
            root: merged(childRootFlat, into: parent.root, explicitType: childRoot.type),
            nodes: nodes
        )
    }

    /// A scene Godot imports from another format, as one node: its root, typed by its `.import`
    /// file, and none of its own nodes, which no text file holds.
    private func importedScene(resourcePath: String) throws -> FlatScene {
        let importFile: ImportFile
        do {
            importFile = try catalogue.importFile(for: resourcePath)
        } catch let error as ParseError {
            throw error
        } catch {
            throw ResolveError.sceneNotReadable(resourcePath)
        }
        var name = resourcePath.split(separator: "/").last.map(String.init) ?? resourcePath
        if let dot = name.firstIndex(of: ".") { name = String(name[..<dot]) }
        if case .string(let rootName)? = importFile.param("nodes/root_name"), !rootName.isEmpty { name = rootName }
        return FlatScene(
            resourcePath: resourcePath,
            root: FlatNode(
                path: [],
                name: name,
                type: importFile.sceneRootType,
                scriptPath: nil,
                uniqueInOwner: false,
                groups: [],
                instanceScenePath: nil,
                importedScene: true
            ),
            nodes: []
        )
    }

    /// Whether `node` is a scene's change to a node inside an imported scene: an entry with no
    /// type and no instance, so one that changes a node another scene declares, at a path no
    /// text scene declares, below an imported scene's root. Such a node is left out with the
    /// rest of the imported scene's own nodes, since nothing here says what class it is.
    private func overridesImportedNode(
        _ node: SceneFile.NodeEntry,
        at path: [String],
        rootImported: Bool,
        nodes: [FlatNode],
        index: [String: Int]
    ) -> Bool {
        guard node.type == nil, node.instance == nil, index[path.joined(separator: "/")] == nil else { return false }
        if rootImported { return true }
        return (1..<path.count).contains { length in
            index[path.prefix(length).joined(separator: "/")].map { nodes[$0].importedScene } ?? false
        }
    }

    private func parentPathComponents(_ parent: String) -> [String] {
        if parent == "." { return [] }
        return parent.split(separator: "/").map(String.init)
    }

    /// Groups compose as an ordered union: the base scene's entries in
    /// their own order, then the entries the derived scene adds.
    /// `packed_scene.cpp:1086-1109` writes only the entries no scene in
    /// the pack stack already declares, and `:586-589` adds every
    /// recorded entry to whatever the base instantiation put there.
    static func unionGroups(_ base: [String], _ derived: [String]) -> [String] {
        var groups = base
        for group in derived where !groups.contains(group) { groups.append(group) }
        return groups
    }

    /// A node at a path already present (an override of an inherited or
    /// instanced node) merges into it: explicit values win, the rest is
    /// kept.
    private func appendOrMerge(
        _ flat: FlatNode,
        explicitType: String?,
        into nodes: inout [FlatNode],
        index: inout [String: Int]
    ) {
        let key = flat.path.joined(separator: "/")
        guard let existing = index[key] else {
            index[key] = nodes.count
            nodes.append(flat)
            return
        }
        nodes[existing] = merged(flat, into: nodes[existing], explicitType: explicitType)
    }

    private func merged(_ flat: FlatNode, into existing: FlatNode, explicitType: String?) -> FlatNode {
        FlatNode(
            path: flat.path,
            name: flat.name,
            type: explicitType ?? existing.type,
            scriptPath: flat.scriptPath ?? existing.scriptPath,
            uniqueInOwner: flat.uniqueInOwner || existing.uniqueInOwner,
            groups: SceneResolver.unionGroups(existing.groups, flat.groups),
            instanceScenePath: flat.instanceScenePath ?? existing.instanceScenePath,
            instancedRootScriptPath: flat.instancedRootScriptPath ?? existing.instancedRootScriptPath,
            ownerPath: existing.ownerPath,
            importedScene: flat.importedScene || existing.importedScene
        )
    }

    /// The node, plus the instanced scene's own nodes re-rooted under it
    /// when that scene's root has no script. An instance whose root is
    /// scripted is a boundary: its type and script are read, its children
    /// belong to that script.
    private func makeFlatNode(
        node: SceneFile.NodeEntry,
        path: [String],
        scene: SceneFile,
        visiting: inout [String]
    ) throws -> (FlatNode, [FlatNode]) {
        let scriptPath = try resolveScriptPath(of: node, in: scene)
        var instancePath: String? = nil
        var instancedRootScript: String? = nil
        var type = node.type ?? "Node"
        var innerNodes: [FlatNode] = []
        var groups = node.groups
        var imported = false
        if let instanceId = node.instance, let ext = scene.extResource(id: instanceId) {
            instancePath = ext.path
            let inner = try flattenImpl(resourcePath: ext.path, visiting: &visiting)
            type = inner.root.type
            imported = inner.root.importedScene
            instancedRootScript = inner.root.scriptPath
            groups = SceneResolver.unionGroups(inner.root.groups, node.groups)
            if instancedRootScript == nil {
                innerNodes = inner.nodes.map { n in
                    FlatNode(
                        path: path + n.path,
                        name: n.name,
                        type: n.type,
                        scriptPath: n.scriptPath,
                        uniqueInOwner: false,
                        groups: n.groups,
                        instanceScenePath: n.instanceScenePath,
                        instancedRootScriptPath: n.instancedRootScriptPath,
                        ownerPath: path + n.ownerPath,
                        importedScene: n.importedScene
                    )
                }
            }
        }
        var uniqueInOwner = false
        if case .bool(let b) = node.prop("unique_name_in_owner") ?? .null { uniqueInOwner = b }
        let flat = FlatNode(
            path: path,
            name: path.last ?? node.name,
            type: type,
            scriptPath: scriptPath,
            uniqueInOwner: uniqueInOwner,
            groups: groups,
            instanceScenePath: instancePath,
            instancedRootScriptPath: instancedRootScript,
            importedScene: imported
        )
        return (flat, innerNodes)
    }

    private func resolveScriptPath(of node: SceneFile.NodeEntry, in scene: SceneFile) throws -> String? {
        guard case .extResource(let id) = node.prop("script") ?? .null else { return nil }
        return scene.extResource(id: id)?.path
    }
}
