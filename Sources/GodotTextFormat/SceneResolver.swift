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
                childRoot: root
            )
        }

        guard let rootType = root.type else {
            throw ResolveError.notAScene(resourcePath)
        }

        var nodes: [FlatNode] = []
        for node in scene.nodes.dropFirst() {
            guard let parentPath = node.parentPath else { continue }
            let path = parentPathComponents(parentPath) + [node.name]
            nodes.append(try makeFlatNode(
                node: node,
                path: path,
                scene: scene
            ))
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
        childRoot: SceneFile.NodeEntry
    ) throws -> FlatScene {
        var nodes = parent.nodes
        var pathIndex: [String: Int] = [:]
        for (i, n) in nodes.enumerated() {
            pathIndex[n.path.joined(separator: "/")] = i
        }

        for node in child.nodes.dropFirst() {
            guard let parentPath = node.parentPath else { continue }
            let pathComponents = parentPathComponents(parentPath) + [node.name]
            let key = pathComponents.joined(separator: "/")

            let flat = try makeFlatNode(node: node, path: pathComponents, scene: child)
            if let existing = pathIndex[key] {
                // Override: child values win when specified; otherwise keep parent's.
                // Type follows child's explicit type=, else parent's.
                let merged = FlatNode(
                    path: flat.path,
                    name: flat.name,
                    type: node.type ?? nodes[existing].type,
                    scriptPath: flat.scriptPath ?? nodes[existing].scriptPath,
                    uniqueInOwner: flat.uniqueInOwner || nodes[existing].uniqueInOwner,
                    groups: flat.groups.isEmpty ? nodes[existing].groups : flat.groups,
                    instanceScenePath: flat.instanceScenePath ?? nodes[existing].instanceScenePath
                )
                nodes[existing] = merged
            } else {
                pathIndex[key] = nodes.count
                nodes.append(flat)
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

    private func makeFlatNode(
        node: SceneFile.NodeEntry,
        path: [String],
        scene: SceneFile
    ) throws -> FlatNode {
        let scriptPath = try resolveScriptPath(of: node, in: scene)

        var instancePath: String? = nil
        var type = node.type ?? "Node"
        if let instanceId = node.instance, let ext = scene.extResource(id: instanceId) {
            instancePath = ext.path
            // Nested scene instances are opaque boundaries — we resolve the root
            // type of the instanced scene (so the accessor type is correct) but
            // do NOT recurse into its children. Per project convention.
            let inner = try catalogue.sceneFile(at: ext.path)
            if let t = inner.rootNode?.type {
                type = t
            }
        }

        var uniqueInOwner = false
        if case .bool(let b) = node.prop("unique_name_in_owner") ?? .null { uniqueInOwner = b }

        return FlatNode(
            path: path,
            name: path.last ?? node.name,
            type: type,
            scriptPath: scriptPath,
            uniqueInOwner: uniqueInOwner,
            groups: node.groups,
            instanceScenePath: instancePath
        )
    }

    private func resolveScriptPath(of node: SceneFile.NodeEntry, in scene: SceneFile) throws -> String? {
        guard case .extResource(let id) = node.prop("script") ?? .null else { return nil }
        return scene.extResource(id: id)?.path
    }
}
