public struct SceneResolver {
    public let catalogue: SceneCatalogue

    public init(catalogue: SceneCatalogue) {
        self.catalogue = catalogue
    }

    public func flatten(resourcePath: String) throws -> FlatScene {
        let scene = try catalogue.sceneFile(at: resourcePath)
        guard let root = scene.rootNode else {
            throw ResolveError.notAScene(resourcePath)
        }
        guard let rootType = root.type else {
            // No type — this is an inherited scene. Task 13 handles that.
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
            // Nested instance boundary — type comes from the instanced scene's root.
            // Task 14 locks this behavior in; for now we resolve type if we can.
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
