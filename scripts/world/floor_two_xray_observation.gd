extends RefCounted
## Gesture evidence is spatial: a nearby, unobscured target must actually lie
## inside the live hand window. Merely enabling a camera never earns a lesson.

static func visible_targets(layout: Dictionary, camera: Camera3D, player: Vector3, frame: Rect2, viewport_size: Vector2, occluded_ui: Rect2 = Rect2()) -> Array[String]:
	var result: Array[String] = []
	if not is_instance_valid(camera) or frame.size.x <= 0 or frame.size.y <= 0 or viewport_size.x <= 0 or viewport_size.y <= 0:
		return result
	for target: Dictionary in layout.get("xray_targets", []):
		var point: Vector3 = target.get("position", Vector3.ZERO)
		if not point.is_finite() or player.distance_to(point) > float(target.get("max_distance", 12.0)) or camera.is_position_behind(point):
			continue
		var pixel := camera.unproject_position(point)
		if not frame.has_point(pixel / viewport_size) or occluded_ui.has_point(pixel):
			continue
		var query := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
		var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(point) > 0.65:
			continue
		result.append(str(target.get("id", "")))
	return result
