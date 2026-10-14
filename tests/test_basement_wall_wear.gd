extends SceneTree

const Atmosphere = preload("res://scripts/world/basement_atmosphere.gd")
var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var first := Atmosphere.new()
	var second := Atmosphere.new()
	root.add_child(first)
	root.add_child(second)
	first._build_wall_wear()
	second._round = 4
	second._build_wall_wear()
	var signatures: Array[int] = []
	var strokes := 0
	var smudges := 0
	_check(first.get_child_count() == 5, "wall wear covers five authored surfaces")
	for index in first.get_child_count():
		var mesh := first.get_child(index) as MeshInstance3D
		var other := second.get_child(index) as MeshInstance3D
		_check(mesh.mesh is ArrayMesh, "wear uses individual contour geometry, not quad cards")
		var arrays := mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var signature := hash(vertices)
		_check(not signatures.has(signature), "different walls never reuse a scratch pattern")
		signatures.append(signature)
		_check(vertices == other.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "fixed authoring seed reproduces marks across visits/reloads")
		var material := mesh.material_override as StandardMaterial3D
		_check(material.albedo_texture == null and material.vertex_color_use_as_albedo, "no repeated rectangular damage texture")
		_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "stroke edges blend with existing wallpaper")
		_check(not material.no_depth_test, "wall marks remain occluded by the wall from the other side")
		_check(mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "thin old marks do not cast detached shadows")
		var invisible_edges := 0
		for color in colors:
			_check(color.a <= 0.341, "graphite marks remain subdued")
			if color.a == 0.0:
				invisible_edges += 1
		_check(invisible_edges > colors.size() / 3, "irregular stroke and smudge edges fade fully transparent")
		strokes += int(mesh.get_meta("stroke_count"))
		smudges += int(mesh.get_meta("smudge_count"))
		# Validate the actual emitted geometry, not only proposed mark centres:
		# clock, switch and painting exclusion areas remain clear.
		var excluded: Array = mesh.get_meta("protected_areas")
		for point in vertices:
			var wall_point := Vector2(point.z, point.y) if str(mesh.name) in ["WallWearEast", "WallWearWest"] else Vector2(point.x, point.y)
			for region: Rect2 in excluded:
				_check(not region.has_point(wall_point), "wear geometry avoids framed art, clock and switch")
	_check(strokes >= 55 and smudges >= 8, "more dispersed distinct marks replace the four identical patch blocks")
	_check(first.find_children("*", "CollisionObject3D", true, false).is_empty(), "decorative marks never alter wall collision or movement")
	print("wall wear: ", strokes, " unique strokes, ", smudges, " soft irregular smudges")
	first.free()
	second.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("basement wall wear tests passed")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)
