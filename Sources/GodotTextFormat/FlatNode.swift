public struct FlatScene: Equatable {
    public let resourcePath: String
    /// The scene's root, resolved through inheritance: an empty `path` and
    /// the concrete Godot class the scene instantiates.
    public let root: FlatNode
    /// The root's descendants, in the order the scene declares them.
    public let nodes: [FlatNode]
    public init(resourcePath: String, root: FlatNode, nodes: [FlatNode]) {
        self.resourcePath = resourcePath
        self.root = root
        self.nodes = nodes
    }
}

public struct FlatNode: Equatable {
    public let path: [String]              // relative to root, e.g. ["Spinner", "Body"]
    public let name: String                // leaf name (last component of path)
    public let type: String                // concrete Godot type (resolved if possible)
    public let scriptPath: String?         // res://... if node has `script = ExtResource("id")`
    public let uniqueInOwner: Bool
    public let groups: [String]
    public let instanceScenePath: String?  // res://... when this node is a nested scene boundary
    /// When this node is an instanced sub-scene (`instanceScenePath != nil`)
    /// and the inner scene's root has a `script = ExtResource(...)` line,
    /// the resolved `res://...` path of that script. Used by SceneGen to
    /// type the NodeRef as the script's user class instead of the engine
    /// class. Nil for non-instanced nodes and for instanced scenes whose
    /// root has no script attached.
    public let instancedRootScriptPath: String?

    public init(
        path: [String],
        name: String,
        type: String,
        scriptPath: String?,
        uniqueInOwner: Bool,
        groups: [String],
        instanceScenePath: String?,
        instancedRootScriptPath: String? = nil
    ) {
        self.path = path
        self.name = name
        self.type = type
        self.scriptPath = scriptPath
        self.uniqueInOwner = uniqueInOwner
        self.groups = groups
        self.instanceScenePath = instanceScenePath
        self.instancedRootScriptPath = instancedRootScriptPath
    }
}
