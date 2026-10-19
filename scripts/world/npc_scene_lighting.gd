extends Node3D
## The shadow occupies the portrait's actual alpha-cut plane, not a capsule
## enclosing it. A surrounding volume incorrectly shadows the portrait itself.
## Orient this ordinary (non-shader-billboard) plane from the owning viewport
## once per frame: shadow passes and the secondary X-ray camera share one pose.

var _portrait: Sprite3D
var _silhouette: Sprite3D

static func apply(actor: Node3D, portrait: Sprite3D, _height: float) -> void:
	portrait.shaded = true
	portrait.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portrait.set_meta("floor_independent_color", false)
	actor.set_meta("environment_lit", true)
	if actor.has_node("NPCShadowBody"):
		return
	var shadow: Node3D = load("res://scripts/world/npc_scene_lighting.gd").new()
	shadow.name = "NPCShadowBody"
	shadow._portrait = portrait
	shadow.process_priority = 100
	var silhouette := Sprite3D.new()
	silhouette.name = "PortraitSilhouette"
	silhouette.texture = portrait.texture
	silhouette.pixel_size = portrait.pixel_size
	silhouette.centered = portrait.centered
	silhouette.offset = portrait.offset
	silhouette.axis = portrait.axis
	silhouette.flip_h = portrait.flip_h
	silhouette.flip_v = portrait.flip_v
	silhouette.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	silhouette.alpha_scissor_threshold = portrait.alpha_scissor_threshold
	silhouette.texture_filter = portrait.texture_filter
	silhouette.double_sided = true
	silhouette.shaded = true
	silhouette.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	shadow._silhouette = silhouette
	shadow.add_child(silhouette)
	actor.add_child(shadow)

func _process(_delta: float) -> void:
	if not is_instance_valid(_portrait) or not is_instance_valid(_silhouette):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Match Godot 4.6's SpriteBase3D billboard basis, including retained scale.
	# CPU orientation remains unambiguous when another viewport renders shadows.
	var facing := camera.global_basis.orthonormalized()
	if _portrait.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y:
		var right := Vector3.UP.cross(facing.z).normalized()
		var forward := facing.x.cross(Vector3.UP).normalized()
		if right.is_zero_approx() or forward.is_zero_approx():
			return
		facing = Basis(right, Vector3.UP, forward)
	elif _portrait.billboard == BaseMaterial3D.BILLBOARD_DISABLED:
		facing = _portrait.global_basis.orthonormalized()
	var portrait_scale := _portrait.global_basis.get_scale()
	var scaled_facing := Basis(facing.x * portrait_scale.x, facing.y * portrait_scale.y, facing.z * portrait_scale.z)
	_silhouette.global_transform = Transform3D(scaled_facing, _portrait.global_position)
	_silhouette.visible = _portrait.is_visible_in_tree()
