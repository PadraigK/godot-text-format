# godot-text-format

A parser for Godot's text formats (`.tscn`, `.tres`, `project.godot`) into a structured model: `SceneFile`, `ResourceFile`, `ProjectFile`, and `FlatScene` (a scene resolved through inheritance and instancing by `SceneResolver` over a `SceneCatalogue`). It depends on nothing but the standard library and Foundation.

Used by gdswift and by the Embedded Swift bindings' `scenegen` tool, both by relative path: the repos sit side by side in `~/code/work` (`/mnt/work` on the VM), and a path dependency builds this working copy, so a change here reaches both on their next build. Before changing public API, build and test both consumers.

Extracted from gdswift (`Sources/GodotTextFormat`, `Tests/GodotTextFormatTests`) on 2026-09-24 with its history.

`swift test` runs the tests; the fixtures include real scenes from user projects.
