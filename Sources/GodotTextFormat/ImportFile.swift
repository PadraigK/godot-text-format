/// The `.import` file Godot keeps beside a file it imports (a texture, a sound, a model): the
/// importer that reads the file, the class the result loads as, and the import settings.
public struct ImportFile {
    /// `[remap]`'s `importer`: `scene` for a model imported as a scene, `texture`, `wav`, ….
    public let importer: String?
    /// `[remap]`'s `type`, the class the imported file loads as: `PackedScene`,
    /// `CompressedTexture2D`, ….
    public let type: String?
    /// `[params]`: the import settings by name, in the file's order.
    public let params: [(String, Value)]

    public static func parse(_ source: String) throws -> ImportFile {
        var lexer = Lexer(source: source)
        let tokens = try lexer.tokenize()
        var parser = SectionParser(tokens: tokens)
        let sections = try parser.parseDocument()
        let remap = sections.first { $0.kind == "remap" }
        func text(_ name: String) -> String? {
            guard case .string(let value)? = remap?.prop(name) else { return nil }
            return value
        }
        return ImportFile(
            importer: text("importer"),
            type: text("type"),
            params: sections.first { $0.kind == "params" }?.body ?? []
        )
    }

    public func param(_ name: String) -> Value? {
        params.first { $0.0 == name }?.1
    }

    /// The class the root node of the scene Godot imports from this file is taken to be: the
    /// import dock's Root Type (`nodes/root_type`) when it names a class, and `Node3D`, which
    /// the importers' own roots are, when it is empty. `Node` when a script decides the class
    /// and nothing here says which: a Root Type that is a script's global class
    /// (`Enemy (enemy.gd)`), or a Root Script (`nodes/root_script`) with no Root Type, whose
    /// base class the root takes. A post-import script that returns another root isn't seen.
    public var sceneRootType: String {
        if case .string(let rootType)? = param("nodes/root_type"), !rootType.isEmpty {
            return rootType.contains(" ") ? "Node" : rootType
        }
        switch param("nodes/root_script") {
        case nil, .null?: return "Node3D"
        default: return "Node"
        }
    }
}
