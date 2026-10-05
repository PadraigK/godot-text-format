# godot-text-format

A Swift parser for Godot 4's text formats: scenes (`.tscn`), resources (`.tres`) and `project.godot`. It reads each file into a typed model. It can also flatten a scene into a single list of nodes. Nodes from the scene it inherits from, and from the scenes instanced inside it, are merged into the list.

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
- `AnimationExtractor` (animation players and their library and animation names) and `InputActionsExtractor` (input actions, with platform variants).
- `ProjectFile.appendingAutoload(name:path:to:)`, which adds an autoload to `project.godot`'s text.

A parse failure throws `ParseError`, with the line and column.

## Tests

`swift test`.

## Licence

MIT, see `LICENSE`.
