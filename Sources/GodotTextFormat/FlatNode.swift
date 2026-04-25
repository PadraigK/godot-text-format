public struct FlatScene: Equatable {
    public let resourcePath: String
    public let rootType: String           // concrete Godot class (resolved through inheritance)
    public let rootScriptPath: String?    // res://... from root node's `script = ExtResource("id")`
    public let rootNodeName: String
    public let nodes: [FlatNode]
    public init(
        resourcePath: String,
        rootType: String,
        rootScriptPath: String?,
        rootNodeName: String,
        nodes: [FlatNode]
    ) {
        self.resourcePath = resourcePath
        self.rootType = rootType
        self.rootScriptPath = rootScriptPath
        self.rootNodeName = rootNodeName
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
