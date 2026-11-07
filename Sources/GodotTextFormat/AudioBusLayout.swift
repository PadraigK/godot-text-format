extension ProjectFile {
    /// The path Godot loads the default bus layout from when the project doesn't set one.
    public static let godotDefaultBusLayout = "res://default_bus_layout.tres"

    /// The bus layout the project sets, `[audio]`'s `buses/default_bus_layout`, as a `res://` path
    /// or a `uid://` (Godot's editor writes the uid); nil when it doesn't set one, and Godot loads
    /// `godotDefaultBusLayout` when that file exists.
    public var defaultBusLayout: String? {
        guard case .string(let path)? = section("audio")?.prop("buses/default_bus_layout") else { return nil }
        return path
    }
}

public enum AudioBusLayoutReader {
    /// The bus names of a bus layout file, by index, as `AudioServer.set_bus_layout` gives them to
    /// the buses: bus 0 is `Master` whatever the file says, a bus the file names nothing has an
    /// empty name, and buses go up to the highest index any `bus/<index>/…` line gives, as
    /// `AudioBusLayout` grows its list to fit each. Nil for a file of another type.
    public static func busNames(in file: ResourceFile) -> [String]? {
        guard file.type == "AudioBusLayout" else { return nil }
        var names = ["Master"]
        for (key, value) in file.resource?.body ?? [] {
            let parts = key.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count >= 3, parts[0] == "bus", let index = Int(parts[1]), index >= 0 else { continue }
            while names.count <= index {
                names.append("")
            }
            guard index > 0, parts.count == 3, parts[2] == "name" else { continue }
            switch value {
            case .stringName(let name), .string(let name): names[index] = name
            default: continue
            }
        }
        return names
    }
}
