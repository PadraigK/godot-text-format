extends SceneTree

func _init():
	# An animation library: three animations with value, position and method tracks.
	var library := AnimationLibrary.new()
	for entry in [["idle", 1.0], ["walk", 0.5], ["Take 001", 2.0]]:
		var animation := Animation.new()
		animation.length = entry[1]
		animation.loop_mode = Animation.LOOP_LINEAR
		var value := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(value, NodePath("Body/Sprite:modulate:a"))
		animation.track_insert_key(value, 0.0, 1.0)
		animation.track_insert_key(value, entry[1], 0.25)
		var position := animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(position, NodePath("Skeleton3D:hip"))
		animation.position_track_insert_key(position, 0.0, Vector3(0, 1, 0))
		animation.position_track_insert_key(position, entry[1], Vector3(0.5, 1, -2))
		library.add_animation(entry[0], animation)
	_save(library, "library")

	# Sprite frames: two animations whose frames are a sub-resource texture.
	var frames := SpriteFrames.new()
	var texture := PlaceholderTexture2D.new()
	texture.size = Vector2(16, 24)
	frames.remove_animation("default")
	for name in ["run", "jump_up"]:
		frames.add_animation(name)
		frames.set_animation_speed(name, 12.0)
		frames.set_animation_loop(name, name == "run")
		frames.add_frame(name, texture, 1.0)
		frames.add_frame(name, texture, 2.5)
	_save(frames, "frames")

	# One value of each kind the binary format can hold, as metadata of a plain resource.
	var holder := Resource.new()
	holder.resource_name = "Holder"
	var inner := Gradient.new()
	inner.colors = PackedColorArray([Color(1, 0, 0, 1), Color(0, 0, 1, 0.5)])
	var values := {
		"a_bool": true,
		"an_int": -42,
		"a_big_int": 5000000000,
		"a_float": 1.5,
		"a_string": "héllo wörld",
		"a_string_name": &"take_hit",
		"a_vector2": Vector2(1.5, -2),
		"a_vector2i": Vector2i(3, -4),
		"a_rect2": Rect2(1, 2, 3, 4),
		"a_rect2i": Rect2i(1, 2, 3, 4),
		"a_vector3": Vector3(1, 2.5, 3),
		"a_vector3i": Vector3i(1, 2, 3),
		"a_vector4": Vector4(1, 2, 3, 4.5),
		"a_vector4i": Vector4i(1, 2, 3, 4),
		"a_plane": Plane(0, 1, 0, 2.5),
		"a_quaternion": Quaternion(0, 0, 0, 1),
		"an_aabb": AABB(Vector3(1, 2, 3), Vector3(4, 5, 6)),
		"a_basis": Basis(Vector3(1, 0, 0), Vector3(0, 2, 0), Vector3(0, 0, 3)),
		"a_transform2d": Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(5, 6)),
		"a_transform3d": Transform3D(Basis.IDENTITY, Vector3(7, 8, 9)),
		"a_projection": Projection.IDENTITY,
		"a_color": Color(0.25, 0.5, 0.75, 1),
		"a_node_path": NodePath("/root/Main/Player:position:x"),
		"a_relative_path": NodePath("../Sibling"),
		"a_dictionary": {"name": &"idle", 3: [1, 2.5, "three"], "nested": {"deep": true}},
		"an_array": [1, "two", Vector2(3, 3), null],
		"bytes": PackedByteArray([1, 2, 3]),
		"int32s": PackedInt32Array([1, -2, 3]),
		"int64s": PackedInt64Array([5000000000, -1]),
		"float32s": PackedFloat32Array([0.5, 1.5]),
		"float64s": PackedFloat64Array([0.25, 2.5]),
		"strings": PackedStringArray(["one", "twö"]),
		"vector2s": PackedVector2Array([Vector2(1, 2), Vector2(3, 4)]),
		"vector3s": PackedVector3Array([Vector3(1, 2, 3)]),
		"colors": PackedColorArray([Color(1, 0, 0, 1)]),
		"vector4s": PackedVector4Array([Vector4(1, 2, 3, 4)]),
		"a_sub_resource": inner,
		"an_ext_resource": load("res://frames.tres"),
	}
	for key in values:
		holder.set_meta(key, values[key])
	_save(holder, "values")
	quit()

func _save(resource: Resource, name: String) -> void:
	for target in [[name + ".tres", 0], [name + ".res", 0], [name + "-compressed.res", ResourceSaver.FLAG_COMPRESS]]:
		var error := ResourceSaver.save(resource, "res://" + target[0], target[1])
		if name == "library":
			error = ResourceSaver.set_uid("res://" + target[0], ResourceUID.text_to_id("uid://bw6o1pq4ksl5j"))
		print("SAVE ", target[0], " ", error)
