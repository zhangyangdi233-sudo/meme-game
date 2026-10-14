extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var asset: Node3D = load("res://assets/chapter1/Basement_Loop_v2.glb").instantiate()
	root.add_child(asset)
	for node: Node in asset.find_children("*", "Node3D", true, false):
		if str(node.name).begins_with("Prop_") and node.get_parent() == asset or str(node.name).contains("Ceiling") or str(node.name).contains("Opal") or str(node.name).contains("Wall_") or str(node.name).contains("PointLight") or str(node.name).contains("Stairwell"):
			print(node.name, " pos=", node.position, " scale=", node.scale, " parent=", node.get_parent().name, " bounds=", (node.global_transform * node.get_aabb()) if node is MeshInstance3D else "")
	asset.free()
	quit()
