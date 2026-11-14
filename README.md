# godot-text-format

A Swift parser for Godot 4's text formats: scenes (`.tscn`), resources (`.tres`), `project.godot` and `.import` files, and a reader for its binary resources (`.res`), plus the `uid://` a file declares and the `class_name` and `extends` at the top of a GDScript file. It reads each file into a typed model. It can also flatten a scene into a single list of nodes. Nodes from the scene it inherits from, and from the scenes instanced inside it, are merged into the list.

Most of the code here was written by an LLM.

I made this repo public as a convenience for my own projects. You may use it if you like, but I don't intend to maintain or support it beyond what I need from it.

## Adding it

```swift
.package(url: "https://github.com/padraigk/godot-text-format.git", from: "0.1.0"),
```

and `.product(name: "GodotTextFormat", package: "godot-text-format")` in your target's dependencies.

## Using it

Parse a scene and read its nodes and connections:

```swift
import GodotTextFormat

let scene = try SceneFile.parse(text)
for node in scene.nodes {
    print(node.parentPath ?? "(root)", node.name, node.type ?? "(instance)")
}
for connection in scene.connections {
    print("\(connection.from).\(connection.signal) → \(connection.to).\(connection.method)")
}
```

Flatten a scene, with its inherited and instanced scenes loaded through a catalogue:

```swift
let catalogue = SceneCatalogue { resPath in
    try String(contentsOfFile: projectDir + "/" + resPath.dropFirst("res://".count), encoding: .utf8)
}
let flat = try SceneResolver(catalogue: catalogue).flatten(resourcePath: "res://main.tscn")
for node in flat.nodes {
    print(node.path.joined(separator: "/"), node.type)
}
```

## What's in it

- `SceneFile`, `ResourceFile` and `ProjectFile` provide the file's sections, external and sub-resources, nodes, connections and properties.
- `Value`, a property value in Godot's variant syntax: numbers, strings, `StringName`s, node paths, constructors such as `Vector2(1, 2)`, arrays, dictionaries, typed arrays and dictionaries, `Object(…)`, hex colours and resource references.
- `SceneResolver` over a `SceneCatalogue`: inherited scenes, instanced scenes, unique names, groups and script attachments, with cycle detection.
- `ResourceFile.parse(binary:)`, a binary resource file (`.res`, or a binary scene's `.scn`) read into the shape a text one has, values as the text format spells them, and `ResourceFile.type(ofBinary:)`, the class of the resource it holds from the start of the file alone. Files Godot's editor saved compressed are read too, through Zstandard's own decoder.
- `ImportFile`, the `.import` file beside a file Godot imports: its importer, the class it loads as and its import settings. The resolver reads it for a model (`.glb`, `.gltf`, `.fbx`, `.blend`) a scene instances or inherits: the model is one node, of the class its Root Type gives or `Node3D`, marked `importedScene`, and none of the nodes inside it, which no text file holds.
- `AnimationExtractor` (the libraries a scene attaches to its animation mixers, whatever their class, with their animation names or their file; the names in a library file; the names in each SpriteFrames, in a scene or a file of its own) and `InputActionsExtractor` (input actions, with platform variants).
- `ProjectFile.autoloads`, the project's autoloads in the order Godot adds them (`[autoload_prepend]`'s first), and `ProjectFile.appendingAutoload(name:path:to:)`, which adds an autoload to `project.godot`'s text.
- `ResourceUIDs`, the `uid://` a file declares for a resource: a scene's or resource's in its header, a script's in the `.uid` file beside it.
- `ScriptHeader`, a GDScript file's `class_name` and what it `extends` (a class by name, or a script by path), read from the lines at its top.

A parse failure throws `ParseError`, with the line and column.

## Zstandard

`Sources/ZstdDecoder/zstddeclib.c` is Zstandard 1.5.7's single-file decoder, unchanged, as its `build/single_file_libs/combine.py` writes it from the release at https://github.com/facebook/zstd. It is under the BSD licence in `Sources/ZstdDecoder/LICENSE`. Godot 4.7 bundles the same version.

## Tests

`swift test`.

## Licence

MIT, see `LICENSE`.
