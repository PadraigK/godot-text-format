extends SceneTree

# Scenes holding another scene in their root's metadata, as the Godot that runs this saves them.
# Run from an empty project's folder with each Godot:
#   godot --headless -s make.gd    writes embedded-last-<major>.<minor>.tscn and embedded-before-<major>.<minor>.tscn
# The embedded scene (Inner, with InnerChild) and the scene itself (Main, with OuterChild) each
# have a persistent connection. In embedded-before, OuterChild's metadata holds a Gradient, a
# sub-resource saved after the embedded scene; in embedded-last the embedded scene is the last
# sub-resource.
func _init():
	var version := Engine.get_version_info()
	for name in ["last", "before"]:
		var path := "res://embedded-%s-%d.%d.tscn" % [name, version.major, version.minor]
		print(path, " ", ResourceSaver.save(_scene(name == "before"), path))
	quit()


func _scene(with_gradient: bool) -> PackedScene:
	var inner := Node3D.new()
	inner.name = "Inner"
	var inner_child := Node.new()
	inner_child.name = "InnerChild"
	inner.add_child(inner_child)
	inner_child.owner = inner
	inner_child.renamed.connect(inner.queue_free, CONNECT_PERSIST)
	var packed := PackedScene.new()
	packed.pack(inner)
	inner.free()

	var main := Node2D.new()
	main.name = "Main"
	main.set_meta("inner_scene", packed)
	var outer_child := Node.new()
	outer_child.name = "OuterChild"
	if with_gradient:
		outer_child.set_meta("gradient", Gradient.new())
	main.add_child(outer_child)
	outer_child.owner = main
	outer_child.renamed.connect(main.queue_free, CONNECT_PERSIST)
	var scene := PackedScene.new()
	scene.pack(main)
	main.free()
	return scene
