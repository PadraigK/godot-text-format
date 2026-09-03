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

        let scene = try catalogue.sceneFile(at: resourcePath)
        guard let root = scene.rootNode else {
            throw ResolveError.notAScene(resourcePath)
        }

        // Inherited scene: root has `instance=` pointing at another scene.
        if let instanceId = root.instance, let ext = scene.extResource(id: instanceId) {
            let parent = try flattenImpl(resourcePath: ext.path, visiting: &visiting)
            return try merge(
                parent: parent,
                child: scene,
                childResourcePath: resourcePath,
                childRoot: root,
                visiting: &visiting
            )
        }

        guard let rootType = root.type else {
            throw ResolveError.notAScene(resourcePath)
        }

        var nodes: [FlatNode] = []
        var pathIndex: [String: Int] = [:]
        for node in scene.nodes.dropFirst() {
            guard let parentPath = node.parentPath else { continue }
            let path = parentPathComponents(parentPath) + [node.name]
            let (flat, innerNodes) = try makeFlatNode(node: node, path: path, scene: scene, visiting: &visiting)
            appendOrMerge(flat, explicitType: node.type, into: &nodes, index: &pathIndex)
            for inner in innerNodes {
                appendOrMerge(inner, explicitType: inner.type, into: &nodes, index: &pathIndex)
            }
        }

        return FlatScene(
            resourcePath: resourcePath,
            rootType: rootType,
            rootScriptPath: try resolveScriptPath(of: root, in: scene),
            rootNodeName: root.name,
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
            let (flat, innerNodes) = try makeFlatNode(node: node, path: pathComponents, scene: child, visiting: &visiting)
            appendOrMerge(flat, explicitType: node.type, into: &nodes, index: &pathIndex)
            for inner in innerNodes {
                appendOrMerge(inner, explicitType: inner.type, into: &nodes, index: &pathIndex)
            }
        }

        // Root comes from parent (type/script), name from child.
        let childRootScript = try resolveScriptPath(of: childRoot, in: child)
        return FlatScene(
            resourcePath: childResourcePath,
            rootType: parent.rootType,
            rootScriptPath: childRootScript ?? parent.rootScriptPath,
            rootNodeName: childRoot.name,
            nodes: nodes
        )
    }

    private func parentPathComponents(_ parent: String) -> [String] {
        if parent == "." { return [] }
        return parent.split(separator: "/").map(String.init)
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
        nodes[existing] = FlatNode(
            path: flat.path,
            name: flat.name,
            type: explicitType ?? nodes[existing].type,
            scriptPath: flat.scriptPath ?? nodes[existing].scriptPath,
            uniqueInOwner: flat.uniqueInOwner || nodes[existing].uniqueInOwner,
            groups: flat.groups.isEmpty ? nodes[existing].groups : flat.groups,
            instanceScenePath: flat.instanceScenePath ?? nodes[existing].instanceScenePath,
            instancedRootScriptPath: flat.instancedRootScriptPath ?? nodes[existing].instancedRootScriptPath
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
        if let instanceId = node.instance, let ext = scene.extResource(id: instanceId) {
            instancePath = ext.path
            let inner = try flattenImpl(resourcePath: ext.path, visiting: &visiting)
            type = inner.rootType
            instancedRootScript = inner.rootScriptPath
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
                        instancedRootScriptPath: n.instancedRootScriptPath
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
            groups: node.groups,
            instanceScenePath: instancePath,
            instancedRootScriptPath: instancedRootScript
        )
        return (flat, innerNodes)
    }

    private func resolveScriptPath(of node: SceneFile.NodeEntry, in scene: SceneFile) throws -> String? {
        guard case .extResource(let id) = node.prop("script") ?? .null else { return nil }
        return scene.extResource(id: id)?.path
    }
}
